import type { PatchStatus, ManagedApplication, DeferralPhase, UpdatePriority } from "./types"

export const mockApplications: ManagedApplication[] = [
  {
    id: "Google.Chrome",
    name: "Google Chrome",
    enabled: true,
    priority: "High",
    conflictingProcesses: ["chrome.exe"],
    installIfMissing: true,
    deferInitialInstall: false,
    versionPin: { mode: "max", version: "130.0.0.0" },
    requiresReboot: false,
    deferralOverride: { maxCount: 3, deadlineDays: 3 },
  },
  {
    id: "Mozilla.Firefox",
    name: "Mozilla Firefox",
    enabled: true,
    priority: "High",
    conflictingProcesses: ["firefox.exe"],
    installIfMissing: true,
    deferInitialInstall: false,
    versionPin: null,
    requiresReboot: false,
    deferralOverride: null,
  },
  {
    id: "Microsoft.Teams",
    name: "Microsoft Teams",
    enabled: true,
    priority: "High",
    conflictingProcesses: ["Teams.exe", "ms-teams.exe"],
    installIfMissing: true,
    deferInitialInstall: false,
    versionPin: null,
    requiresReboot: false,
    deferralOverride: { maxCount: 3, deadlineDays: 5 },
  },
  {
    id: "Zoom.Zoom",
    name: "Zoom",
    enabled: true,
    priority: "High",
    conflictingProcesses: ["Zoom.exe"],
    installIfMissing: true,
    deferInitialInstall: false,
    versionPin: null,
    requiresReboot: false,
    deferralOverride: { maxCount: 3, deadlineDays: 5 },
  },
  {
    id: "Adobe.Acrobat.Reader.64-bit",
    name: "Adobe Acrobat Reader DC",
    enabled: true,
    priority: "Normal",
    conflictingProcesses: ["AcroRd32.exe", "Acrobat.exe"],
    installIfMissing: true,
    deferInitialInstall: false,
    versionPin: null,
    requiresReboot: false,
    deferralOverride: null,
  },
  {
    id: "7zip.7zip",
    name: "7-Zip",
    enabled: true,
    priority: "Low",
    conflictingProcesses: ["7zFM.exe"],
    installIfMissing: true,
    deferInitialInstall: false,
    versionPin: null,
    requiresReboot: false,
    deferralOverride: null,
  },
  {
    id: "VideoLAN.VLC",
    name: "VLC Media Player",
    enabled: true,
    priority: "Low",
    conflictingProcesses: ["vlc.exe"],
    installIfMissing: true,
    deferInitialInstall: true,
    versionPin: null,
    requiresReboot: false,
    deferralOverride: null,
  },
  {
    id: "Notepad++.Notepad++",
    name: "Notepad++",
    enabled: true,
    priority: "Low",
    conflictingProcesses: ["notepad++.exe"],
    installIfMissing: true,
    deferInitialInstall: false,
    versionPin: null,
    requiresReboot: false,
    deferralOverride: null,
  },
]

export function generateMockPatchStatus(): PatchStatus[] {
  const now = new Date()
  
  return [
    {
      appId: "Google.Chrome",
      appName: "Google Chrome",
      installedVersion: "128.0.6613.120",
      availableVersion: "129.0.6668.89",
      updateAvailable: true,
      priority: "High",
      conflictingProcesses: ["chrome.exe"],
      processesRunning: true,
      lastChecked: now.toISOString(),
      deferralState: {
        appId: "Google.Chrome",
        deferralCount: 1,
        firstNotification: new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString(),
        lastDeferral: new Date(now.getTime() - 4 * 60 * 60 * 1000).toISOString(),
        targetVersion: "129.0.6668.89",
        deadlineDate: new Date(now.getTime() + 48 * 60 * 60 * 1000).toISOString(),
        phase: "Approaching",
        maxDeferrals: 3,
      },
    },
    {
      appId: "Mozilla.Firefox",
      appName: "Mozilla Firefox",
      installedVersion: "130.0",
      availableVersion: "131.0.2",
      updateAvailable: true,
      priority: "High",
      conflictingProcesses: ["firefox.exe"],
      processesRunning: false,
      lastChecked: now.toISOString(),
      deferralState: {
        appId: "Mozilla.Firefox",
        deferralCount: 0,
        firstNotification: now.toISOString(),
        lastDeferral: "",
        targetVersion: "131.0.2",
        deadlineDate: new Date(now.getTime() + 168 * 60 * 60 * 1000).toISOString(),
        phase: "Initial",
        maxDeferrals: 5,
      },
    },
    {
      appId: "Adobe.Acrobat.Reader.64-bit",
      appName: "Adobe Acrobat Reader DC",
      installedVersion: "24.002.20857",
      availableVersion: "24.003.20112",
      updateAvailable: true,
      priority: "Normal",
      conflictingProcesses: ["AcroRd32.exe"],
      processesRunning: false,
      lastChecked: now.toISOString(),
      deferralState: {
        appId: "Adobe.Acrobat.Reader.64-bit",
        deferralCount: 4,
        firstNotification: new Date(now.getTime() - 144 * 60 * 60 * 1000).toISOString(),
        lastDeferral: new Date(now.getTime() - 1 * 60 * 60 * 1000).toISOString(),
        targetVersion: "24.003.20112",
        deadlineDate: new Date(now.getTime() + 12 * 60 * 60 * 1000).toISOString(),
        phase: "Imminent",
        maxDeferrals: 5,
      },
    },
    {
      appId: "7zip.7zip",
      appName: "7-Zip",
      installedVersion: "24.07",
      availableVersion: "24.08",
      updateAvailable: true,
      priority: "Low",
      conflictingProcesses: ["7zFM.exe"],
      processesRunning: false,
      lastChecked: now.toISOString(),
      deferralState: {
        appId: "7zip.7zip",
        deferralCount: 5,
        firstNotification: new Date(now.getTime() - 192 * 60 * 60 * 1000).toISOString(),
        lastDeferral: new Date(now.getTime() - 2 * 60 * 60 * 1000).toISOString(),
        targetVersion: "24.08",
        deadlineDate: new Date(now.getTime() - 2 * 60 * 60 * 1000).toISOString(),
        phase: "Elapsed",
        maxDeferrals: 5,
      },
    },
  ]
}

export function getPriorityColor(priority: UpdatePriority): string {
  switch (priority) {
    case "Critical":
      return "text-red-500"
    case "High":
      return "text-orange-400"
    case "Normal":
      return "text-blue-400"
    case "Low":
      return "text-muted-foreground"
  }
}

export function getPhaseColor(phase: DeferralPhase): string {
  switch (phase) {
    case "Elapsed":
      return "bg-red-500/20 text-red-400 border-red-500/30"
    case "Imminent":
      return "bg-orange-500/20 text-orange-400 border-orange-500/30"
    case "Approaching":
      return "bg-yellow-500/20 text-yellow-400 border-yellow-500/30"
    case "Initial":
      return "bg-green-500/20 text-green-400 border-green-500/30"
  }
}

export function getStatusColor(status: string): string {
  switch (status) {
    case "Success":
      return "text-green-400"
    case "Failed":
      return "text-red-400"
    case "InProgress":
      return "text-blue-400"
    case "Deferred":
      return "text-yellow-400"
    case "Pending":
      return "text-muted-foreground"
    default:
      return "text-muted-foreground"
  }
}
