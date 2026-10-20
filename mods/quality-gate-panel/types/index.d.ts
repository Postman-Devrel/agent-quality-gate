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

declare module 'claude-code' {
  interface PluginState {
    'quality-gate-panel': {
      report: GateReport | null
      run: CiRun | null
      branch: string
      note: string
      isHidden: boolean
    }
  }
}
