import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { CiRun, GateReport } from '../types'

const PANE = 'quality-gate'
const POLL_MS = 20000

const report = atom({ plugin: 'quality-gate-panel', key: 'report' } as const, null)
const run = atom({ plugin: 'quality-gate-panel', key: 'run' } as const, null)
const branch = atom({ plugin: 'quality-gate-panel', key: 'branch' } as const, '')
const note = atom({ plugin: 'quality-gate-panel', key: 'note' } as const, '')
const isHidden = atom({ plugin: 'quality-gate-panel', key: 'isHidden' } as const, false)

const ICON = { pass: '●', warn: '●', fail: '●', not_available: '○' } as const
const COLOR = { pass: 'success', warn: 'warning', fail: 'error', not_available: 'inactive' } as const
const SHORT: Record<string, string> = {
  'skills-check': 'skills',
  'contract-lint': 'lint',
  tests: 'tests',
  'ai-readiness': 'ai',
  impact: 'impact',
}

const ratingColor = (r: GateReport) => (r.passed ? 'success' : 'error')

let lastRunKey = ''

/** Reads a report.json; null when missing or not a gate report. */
async function readReport($: any, path: string, source: GateReport['source'], sha?: string) {
  try {
    if (!(await $.fs.exists(path))) return null
    const file = await $.fs.read(path)
    const json = JSON.parse(typeof file === 'string' ? file : file.text)
    if (typeof json.score !== 'number' || !Array.isArray(json.steps)) return null
    return {
      source,
      passed: !!json.passed,
      score: json.score,
      rating: String(json.rating),
      blockers: json.blockers ?? [],
      feedback: json.feedback ?? [],
      steps: json.steps,
      sha,
    } as GateReport
  } catch {
    return null
  }
}

async function refresh($: any) {
  const git = await $.process.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD', 'HEAD'], { timeoutMs: 5000 }).catch(() => null)
  if (!git || git.exitCode !== 0) {
    await update($, note, () => 'not a git repository')
    return
  }
  const [name, head] = git.stdout.trim().split('\n')
  await update($, branch, () => name)

  // Local report: written by ./gate/run-all.sh, instant feedback for the coding agent.
  const local = await readReport($, 'gate-results/report.json', 'local')
  let shown: GateReport | null = local

  // CI: the latest run of the workflow on this branch. Authoritative when it is for HEAD.
  const list = await $.process
    .run(
      ['gh', 'run', 'list', '--workflow', 'quality-gate', '--branch', name, '--limit', '1', '--json', 'databaseId,status,conclusion,headSha,url'],
      { timeoutMs: 20000 },
    )
    .catch(() => null)
  let ci: CiRun | null = null
  if (list && list.exitCode === 0) {
    try {
      const one = JSON.parse(list.stdout)[0]
      if (one) {
        ci = { id: one.databaseId, status: one.status, conclusion: one.conclusion || '', sha: one.headSha, isHead: one.headSha === head, url: one.url }
      }
    } catch {}
    await update($, note, () => '')
  } else {
    await update($, note, () => 'gh unavailable: showing the local report only')
  }
  await update($, run, () => ci)

  // Download the report of a finished CI run for the current commit.
  if (ci && ci.isHead && ci.status === 'completed') {
    const dir = `gate-results/ci/${ci.id}`
    const path = `${dir}/report.json`
    if (!(await $.fs.exists(path))) {
      await $.process
        .run(['gh', 'run', 'download', String(ci.id), '-n', 'gate-report', '-D', dir], { timeoutMs: 60000 })
        .catch(() => null)
    }
    const remote = await readReport($, path, 'ci', ci.sha)
    if (remote) shown = remote
  }
  await update($, report, () => shown)

  // Status line and toast on a change of the CI run.
  if (shown) $.ui.status(`Gate ${shown.rating} ${shown.score}${shown.passed ? '' : ' ✗'}`)
  const key = ci ? `${ci.id}:${ci.status}:${ci.conclusion}` : ''
  if (ci && ci.isHead && key !== lastRunKey) {
    if (lastRunKey !== '') {
      if (ci.status !== 'completed') $.ui.toast(`Gate CI: ${ci.status}`)
      else if (shown?.source === 'ci') $.ui.toast(`Gate CI ${shown.passed ? 'passed' : 'FAILED'}: ${shown.rating} (${shown.score}/100)`)
    }
    lastRunKey = key
  }
}


export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'gate', description: 'Show the quality gate report (local and CI) in a pane' })
    void refresh($)
    $.clock.every(POLL_MS, () => void refresh($))
    return next(e)
  })

  on('command.run', { command: 'gate' }, async $ => {
    await refresh($)
    await $.ui.open({ id: PANE, title: 'Quality gate' })
    await update($, isHidden, () => false)
    return { text: 'Quality gate pane opened.' }
  })

  // A tool call that may have changed the gate result: refresh soon after a local gate run or a push.
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const result = await next(e)
    if (/gate\/|run-all|git push/.test(String((e as any).command ?? ''))) void refresh($)
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const r = await read($, report)
    if (e.props.hasSurvey || !r || (await read($, isHidden))) return next(e)
    const ci = await read($, run)
    const { Box, Text, Button } = $.ui.resolve(e)
    const sha = r.source === 'ci' ? ` ci@${(r.sha ?? '').slice(0, 7)}` : ' local'
    const pending = ci && ci.isHead && ci.status !== 'completed' ? ` · CI ${ci.status}…` : ''
    return (
      <Box>
        <Text bold color={ratingColor(r)}>
          {r.passed ? '✔' : '✘'} Gate {r.rating} {r.score}/100
        </Text>
        <Text dimColor>{sha}{pending}  </Text>
        {r.steps.map(s => (
          <Text color={COLOR[s.status]}>
            {ICON[s.status]} {SHORT[s.step] ?? s.step}{' '}
          </Text>
        ))}
        {r.blockers.length > 0 && <Text color="error"> blockers: {r.blockers.length} </Text>}
        <Button key="hide" label="Hide" onPress={() => update($, isHidden, () => true)} />
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const r = await read($, report)
    const ci = await read($, run)
    const name = await read($, branch)
    const hint = await read($, note)
    if (!r) {
      return (
        <Box flexDirection="column">
          <Text dimColor>No gate report yet on {name || 'this branch'}. Run ./gate/run-all.sh, or push and wait for the CI run.</Text>
          {hint !== '' && <Text color="warning">{hint}</Text>}
        </Box>
      )
    }
    const room = Math.max(3, (e.viewport?.rows ?? 24) - 12)
    return (
      <Box flexDirection="column">
        <Text bold color={ratingColor(r)}>
          {r.passed ? 'PASSED' : 'FAILED'}  rating {r.rating}  {r.score}/100
        </Text>
        <Text dimColor>
          branch {name} · report {r.source === 'ci' ? `from CI (commit ${(r.sha ?? '').slice(0, 7)})` : 'from the local gate run'}
          {ci ? ` · CI run ${ci.id}: ${ci.status}${ci.conclusion ? '/' + ci.conclusion : ''}${ci.isHead ? '' : ' (older commit)'}` : ''}
        </Text>
        <Text> </Text>
        {r.steps.map(s => (
          <Text color={COLOR[s.status]}>
            {ICON[s.status]} {s.step.padEnd(14)} {s.status.padEnd(14)} {s.score ?? '-'}
          </Text>
        ))}
        {r.blockers.length > 0 && (
          <Box flexDirection="column">
            <Text> </Text>
            <Text bold color="error">Blockers</Text>
            {r.blockers.map(b => <Text color="error">- {b}</Text>)}
          </Box>
        )}
        {r.feedback.length > 0 && (
          <Box flexDirection="column">
            <Text> </Text>
            <Text bold>What to fix</Text>
            {r.feedback.slice(0, room).map((f, i) => (
              <Text>
                {i + 1}. [{f.step}] {f.finding}
              </Text>
            ))}
            {r.feedback.length > room && <Text dimColor>… {r.feedback.length - room} more in gate-results/report.md</Text>}
          </Box>
        )}
        {hint !== '' && <Text color="warning">{hint}</Text>}
      </Box>
    )
  })
}
