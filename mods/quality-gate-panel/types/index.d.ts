export type StepStatus = 'pass' | 'warn' | 'fail' | 'not_available'

export type GateStep = {
  step: string
  status: StepStatus
  score: number | null
}

export type GateFinding = { step: string; status: string; finding: string; fix: string }

/** The gate report (report.json written by gate/aggregate.js), plus where it comes from. */
export type GateReport = {
  source: 'local' | 'ci'
  passed: boolean
  score: number
  rating: string
  blockers: string[]
  feedback: GateFinding[]
  steps: GateStep[]
  /** Commit the report is about (CI reports only). */
  sha?: string
}

/** The latest CI run for the checked-out branch. */
export type CiRun = {
  id: number
  status: string
  conclusion: string
  sha: string
  isHead: boolean
  url: string
}

/** One line of the overview: the latest finished gate run of a branch, and its pull request if any. */
export type OverviewRow = {
  branch: string
  pr: number | null
  title: string
  /** Latest non-cancelled run: queued, in_progress or completed. */
  status: string
  conclusion: string
  rating: string
  score: number | null
  passed: boolean | null
  blockers: number
  sha: string
  runId: number
  /** ISO time the run was created. */
  updatedAt: string
  isCurrent: boolean
}

declare module 'claude-code' {
  interface PluginState {
    'quality-gate-panel': {
      report: GateReport | null
      local: GateReport | null
      ciReport: GateReport | null
      run: CiRun | null
      branch: string
      note: string
      isHidden: boolean
      overview: OverviewRow[]
      view: 'auto' | 'local' | 'ci'
      fixOpen: boolean
      branchesOpen: boolean
    }
  }
}
