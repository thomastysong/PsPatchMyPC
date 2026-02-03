"use client"

import { useState, useEffect, useCallback } from "react"
import { TitleBar } from "./title-bar"
import { Sidebar } from "./sidebar"
import { StatusOverview } from "./status-overview"
import { ApplicationList } from "./application-list"
import { PatchProgress } from "./patch-progress"
import { ActivityLog } from "./activity-log"
import type { PatchStatus, InstallationResult } from "@/lib/types"
import { generateMockPatchStatus } from "@/lib/mock-data"

export type ViewMode = "overview" | "applications" | "progress" | "logs" | "settings"

interface LogEntry {
  id: string
  timestamp: string
  type: "info" | "warning" | "error" | "success"
  message: string
  appId?: string
}

export function PatchManagerClient() {
  const [currentView, setCurrentView] = useState<ViewMode>("overview")
  const [patchStatuses, setPatchStatuses] = useState<PatchStatus[]>([])
  const [isScanning, setIsScanning] = useState(false)
  const [isPatching, setIsPatching] = useState(false)
  const [currentInstall, setCurrentInstall] = useState<InstallationResult | null>(null)
  const [installQueue, setInstallQueue] = useState<PatchStatus[]>([])
  const [completedInstalls, setCompletedInstalls] = useState<InstallationResult[]>([])
  const [logs, setLogs] = useState<LogEntry[]>([])

  const addLog = useCallback((type: LogEntry["type"], message: string, appId?: string) => {
    const entry: LogEntry = {
      id: crypto.randomUUID(),
      timestamp: new Date().toISOString(),
      type,
      message,
      appId,
    }
    setLogs((prev) => [entry, ...prev].slice(0, 100))
  }, [])

  const handleScan = useCallback(async () => {
    setIsScanning(true)
    addLog("info", "Starting patch status scan...")
    
    // Simulate scanning delay
    await new Promise((resolve) => setTimeout(resolve, 2000))
    
    const statuses = generateMockPatchStatus()
    setPatchStatuses(statuses)
    
    const updatesCount = statuses.filter((s) => s.updateAvailable).length
    addLog("success", `Scan complete. Found ${updatesCount} available updates.`)
    setIsScanning(false)
  }, [addLog])

  const handleInstallAll = useCallback(async () => {
    const updates = patchStatuses.filter((s) => s.updateAvailable)
    if (updates.length === 0) {
      addLog("warning", "No updates available to install.")
      return
    }

    setIsPatching(true)
    setCurrentView("progress")
    setInstallQueue(updates)
    setCompletedInstalls([])
    addLog("info", `Starting patch cycle for ${updates.length} applications...`)

    for (const update of updates) {
      const result: InstallationResult = {
        appId: update.appId,
        appName: update.appName,
        status: "InProgress",
        exitCode: 0,
        message: `Installing ${update.appName}...`,
        timestamp: new Date().toISOString(),
        duration: 0,
        rebootRequired: false,
        progress: 0,
      }
      
      setCurrentInstall(result)
      addLog("info", `Installing ${update.appName} (${update.installedVersion} -> ${update.availableVersion})`, update.appId)

      // Simulate installation with progress
      for (let i = 0; i <= 100; i += Math.random() * 15 + 5) {
        const progress = Math.min(100, Math.round(i))
        setCurrentInstall((prev) => prev ? { ...prev, progress } : null)
        await new Promise((resolve) => setTimeout(resolve, 200 + Math.random() * 300))
      }

      // Simulate success/failure (90% success rate)
      const success = Math.random() > 0.1
      const finalResult: InstallationResult = {
        ...result,
        status: success ? "Success" : "Failed",
        exitCode: success ? 0 : 1603,
        message: success ? `${update.appName} updated successfully` : `Failed to update ${update.appName}`,
        duration: Math.floor(Math.random() * 30000) + 10000,
        progress: 100,
        rebootRequired: success && Math.random() > 0.8,
      }

      setCompletedInstalls((prev) => [...prev, finalResult])
      setCurrentInstall(null)
      
      if (success) {
        addLog("success", `${update.appName} updated successfully`, update.appId)
        setPatchStatuses((prev) =>
          prev.map((s) =>
            s.appId === update.appId
              ? { ...s, updateAvailable: false, installedVersion: update.availableVersion }
              : s
          )
        )
      } else {
        addLog("error", `Failed to update ${update.appName} (exit code: 1603)`, update.appId)
      }
    }

    setIsPatching(false)
    setInstallQueue([])
    addLog("info", "Patch cycle completed.")
  }, [patchStatuses, addLog])

  const handleInstallSingle = useCallback(async (appId: string) => {
    const update = patchStatuses.find((s) => s.appId === appId && s.updateAvailable)
    if (!update) return

    setIsPatching(true)
    setCurrentView("progress")
    setInstallQueue([update])
    
    const result: InstallationResult = {
      appId: update.appId,
      appName: update.appName,
      status: "InProgress",
      exitCode: 0,
      message: `Installing ${update.appName}...`,
      timestamp: new Date().toISOString(),
      duration: 0,
      rebootRequired: false,
      progress: 0,
    }
    
    setCurrentInstall(result)
    addLog("info", `Installing ${update.appName} (${update.installedVersion} -> ${update.availableVersion})`, update.appId)

    for (let i = 0; i <= 100; i += Math.random() * 15 + 5) {
      const progress = Math.min(100, Math.round(i))
      setCurrentInstall((prev) => prev ? { ...prev, progress } : null)
      await new Promise((resolve) => setTimeout(resolve, 200 + Math.random() * 300))
    }

    const success = Math.random() > 0.1
    const finalResult: InstallationResult = {
      ...result,
      status: success ? "Success" : "Failed",
      exitCode: success ? 0 : 1603,
      message: success ? `${update.appName} updated successfully` : `Failed to update ${update.appName}`,
      duration: Math.floor(Math.random() * 30000) + 10000,
      progress: 100,
      rebootRequired: success && Math.random() > 0.8,
    }

    setCompletedInstalls((prev) => [...prev, finalResult])
    setCurrentInstall(null)
    
    if (success) {
      addLog("success", `${update.appName} updated successfully`, update.appId)
      setPatchStatuses((prev) =>
        prev.map((s) =>
          s.appId === update.appId
            ? { ...s, updateAvailable: false, installedVersion: update.availableVersion }
            : s
        )
      )
    } else {
      addLog("error", `Failed to update ${update.appName} (exit code: 1603)`, update.appId)
    }

    setIsPatching(false)
    setInstallQueue([])
  }, [patchStatuses, addLog])

  const handleDefer = useCallback((appId: string) => {
    setPatchStatuses((prev) =>
      prev.map((s) => {
        if (s.appId === appId && s.deferralState) {
          return {
            ...s,
            deferralState: {
              ...s.deferralState,
              deferralCount: s.deferralState.deferralCount + 1,
              lastDeferral: new Date().toISOString(),
            },
          }
        }
        return s
      })
    )
    const app = patchStatuses.find((s) => s.appId === appId)
    if (app) {
      addLog("info", `Deferred update for ${app.appName}`, appId)
    }
  }, [patchStatuses, addLog])

  // Initial scan on mount
  useEffect(() => {
    handleScan()
    addLog("info", "PsPatchMyPC Client initialized")
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const pendingUpdates = patchStatuses.filter((s) => s.updateAvailable).length

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-background">
      <TitleBar pendingUpdates={pendingUpdates} />
      <div className="flex flex-1 overflow-hidden">
        <Sidebar
          currentView={currentView}
          onViewChange={setCurrentView}
          pendingUpdates={pendingUpdates}
          isPatching={isPatching}
        />
        <main className="flex-1 overflow-auto">
          {currentView === "overview" && (
            <StatusOverview
              patchStatuses={patchStatuses}
              isScanning={isScanning}
              isPatching={isPatching}
              onScan={handleScan}
              onInstallAll={handleInstallAll}
            />
          )}
          {currentView === "applications" && (
            <ApplicationList
              patchStatuses={patchStatuses}
              isPatching={isPatching}
              onInstall={handleInstallSingle}
              onDefer={handleDefer}
            />
          )}
          {currentView === "progress" && (
            <PatchProgress
              currentInstall={currentInstall}
              installQueue={installQueue}
              completedInstalls={completedInstalls}
              isPatching={isPatching}
            />
          )}
          {currentView === "logs" && <ActivityLog logs={logs} />}
          {currentView === "settings" && (
            <div className="p-6">
              <h2 className="text-xl font-semibold text-foreground">Settings</h2>
              <p className="mt-2 text-muted-foreground">
                Configuration managed via config.psd1 and applications.json
              </p>
            </div>
          )}
        </main>
      </div>
    </div>
  )
}
