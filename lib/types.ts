export type DeferralPhase = "Initial" | "Approaching" | "Imminent" | "Elapsed"
export type UpdatePriority = "Critical" | "High" | "Normal" | "Low"
export type InstallationStatus = "Pending" | "InProgress" | "Success" | "Failed" | "Deferred" | "Cancelled"

export interface PatchStatus {
  appId: string
  appName: string
  installedVersion: string
  availableVersion: string
  updateAvailable: boolean
  priority: UpdatePriority
  conflictingProcesses: string[]
  processesRunning: boolean
  lastChecked: string
  deferralState?: DeferralState
}

export interface DeferralState {
  appId: string
  deferralCount: number
  firstNotification: string
  lastDeferral: string
  targetVersion: string
  deadlineDate: string
  phase: DeferralPhase
  maxDeferrals: number
}

export interface InstallationResult {
  appId: string
  appName: string
  status: InstallationStatus
  exitCode: number
  message: string
  timestamp: string
  duration: number
  rebootRequired: boolean
  progress?: number
}

export interface ManagedApplication {
  id: string
  name: string
  enabled: boolean
  priority: UpdatePriority
  conflictingProcesses: string[]
  installIfMissing: boolean
  deferInitialInstall: boolean
  versionPin: {
    mode: string | null
    version: string | null
  } | null
  requiresReboot: boolean
  deferralOverride: {
    maxCount: number
    deadlineDays: number
  } | null
}

export interface PatchCycleResult {
  success: boolean
  message: string
  totalUpdates: number
  installed: number
  failed: number
  deferred: number
  rebootRequired: boolean
  startTime: string
  endTime: string
  duration: number
  results: InstallationResult[]
  correlationId: string
}
