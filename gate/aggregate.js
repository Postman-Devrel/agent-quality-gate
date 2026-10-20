#!/usr/bin/env node
// Aggregates gate-results/*.json into a composite score, a Sonar-style rating
// (A-E), a Markdown report and a machine-readable report.json.
//
// Usage: node gate/aggregate.js [--no-exit-code]
//   GATE_RESULTS_DIR  results folder (default: gate-results)
//   GITHUB_STEP_SUMMARY  when set, the report is appended to it
// Exit code: 0 = gate passed, 1 = gate failed (so it can be a required check).

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const resultsDir = path.resolve(process.env.GATE_RESULTS_DIR || path.join(root, 'gate-results'));

// --- 1. Config ---------------------------------------------------------------
// Minimal parser for quality-gate.yml: "key: value" and one level of nesting.
function parseConfig(text) {
  const cfg = {};
  let section = null;
  for (const raw of text.split('\n')) {
    const line = raw.replace(/#.*$/, '').trimEnd();
    if (!line.trim()) continue;
    const m = line.match(/^(\s*)([\w-]+):\s*(.*)$/);
    if (!m) continue;
    const [, indent, key, value] = m;
    const parse = (v) => (v === 'true' ? true : v === 'false' ? false : /^-?\d+(\.\d+)?$/.test(v) ? Number(v) : v);
    if (!indent.length) {
      if (value === '') { cfg[key] = {}; section = key; } else { cfg[key] = parse(value); section = null; }
    } else if (section) {
      cfg[section][key] = parse(value);
    }
  }
  return cfg;
}

const cfg = parseConfig(fs.readFileSync(path.join(root, 'quality-gate.yml'), 'utf8'));
const STEPS = Object.keys(cfg.weights);
const LETTERS = ['A', 'B', 'C', 'D', 'E'];
const ratingFor = (score) => LETTERS.find((l) => cfg.rating[l] !== undefined && score >= cfg.rating[l]) || 'E';

// --- 2. Load the step results -----------------------------------------------------
const steps = STEPS.map((step) => {
  const file = path.join(resultsDir, `${step}.json`);
  if (!fs.existsSync(file)) {
    return { step, status: 'not_available', score: null, summary: 'No result file: the step did not run', details: [], command: '' };
  }
  return { ...JSON.parse(fs.readFileSync(file, 'utf8')), step };
});

// --- 3. Composite score -----------------------------------------------------------
// not_available steps never count, neither as pass nor as fail.
const counted = steps.filter((s) => s.status !== 'not_available' && typeof s.score === 'number');
const totalWeight = counted.reduce((sum, s) => sum + cfg.weights[s.step], 0);
const score = totalWeight ? Math.round(counted.reduce((sum, s) => sum + s.score * cfg.weights[s.step], 0) / totalWeight) : 0;
const rating = totalWeight ? ratingFor(score) : 'E';

// --- 4. Hard blockers -------------------------------------------------------------
const byStep = Object.fromEntries(steps.map((s) => [s.step, s]));
const blockers = [];
if (cfg.blockers.lint_error && byStep['contract-lint'].status === 'fail') {
  blockers.push('Contract lint reports at least one error');
}
if (cfg.blockers.failing_test && byStep.tests.status === 'fail') {
  blockers.push('At least one test fails (JUnit or Postman collection)');
}
if (cfg.blockers.breaking_impact && (byStep.impact.details || []).some((d) => d && d.breaking === true)) {
  blockers.push('A change breaks at least one consumer (impact)');
}
if (!counted.length) blockers.push('No step produced a usable result');

const minIndex = LETTERS.indexOf(cfg.pass_rating);
const passed = blockers.length === 0 && LETTERS.indexOf(rating) <= minIndex;

// --- 4b. Feedback for the coding agent ---------------------------------------------
// One entry per finding of a step that is not green. "hint" says how to fix it.
const feedback = [];
for (const s of steps.filter((x) => ['warn', 'fail'].includes(x.status))) {
  const items = (s.details || []).filter((d) => d && (d.hint || d.result));
  const useful = items.filter((d) => d.hint);
  for (const d of (useful.length ? useful : [{ result: s.summary }]).slice(0, 8)) {
    feedback.push({ step: s.step, status: s.status, finding: d.result || s.summary, fix: d.hint || 'See the step summary.' });
  }
}

// --- 5. Markdown report -----------------------------------------------------------
const ICON = { pass: '🟢', warn: '🟠', fail: '🔴', not_available: '⚪' };
const cell = (s) => String(s ?? '').replace(/\|/g, '\\|').replace(/\n/g, ' ');

const rows = steps.map((s) => {
  const weight = s.status === 'not_available' ? '–' : `${cfg.weights[s.step]}`;
  const sc = s.status === 'not_available' ? '–' : s.score;
  return `| ${ICON[s.status] || '⚪'} ${s.step} | ${s.status} | ${sc} | ${weight} | ${cell(s.summary)} | ${s.command ? '`' + cell(s.command) + '`' : ''} |`;
});

const lines = [
  '<!-- agent-quality-gate -->',
  `## ${passed ? '✅' : '❌'} Agent quality gate: rating ${rating} (${score}/100)`,
  '',
  `**${passed ? 'PASSED' : 'FAILED'}**. Required: rating ${cfg.pass_rating} or better and no hard blocker.`,
  '',
  '| Step | Status | Score | Weight | Summary | Command |',
  '|------|--------|------:|-------:|---------|---------|',
  ...rows,
  '',
];
if (blockers.length) lines.push('### Blockers', '', ...blockers.map((b) => `- ${b}`), '');
const skipped = steps.filter((s) => s.status === 'not_available');
if (skipped.length) {
  lines.push('### Not available (excluded from the score, never counted as a pass)', '',
    ...skipped.map((s) => `- ⚪ **${s.step}**: ${s.summary}`), '');
}
if (feedback.length) {
  lines.push('### What to fix (for the coding agent)', '',
    ...feedback.map((f, i) => `${i + 1}. **${f.step}** (${f.status}): ${cell(f.finding)}  \n   Fix: ${cell(f.fix)}`), '');
}
for (const s of steps.filter((x) => ['warn', 'fail'].includes(x.status) && (x.details || []).length)) {
  lines.push(`<details><summary>${ICON[s.status]} ${s.step}: details</summary>`, '', '```json',
    JSON.stringify(s.details, null, 2).slice(0, 3000), '```', '', '</details>', '');
}
const markdown = lines.join('\n');

// --- 6. Outputs -------------------------------------------------------------------
fs.mkdirSync(resultsDir, { recursive: true });
fs.writeFileSync(path.join(resultsDir, 'report.md'), markdown);
fs.writeFileSync(path.join(resultsDir, 'report.json'),
  JSON.stringify({ passed, score, rating, blockers, feedback, steps: steps.map(({ step, status, score: sc }) => ({ step, status, score: sc })) }, null, 2));
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown + '\n');
console.log(markdown);

if (!passed && !process.argv.includes('--no-exit-code')) process.exit(1);
