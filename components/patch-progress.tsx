"use client"

import { CheckCircle, XCircle, Loader2, Clock, RotateCw } from "lucide-react"
import type { PatchStatus, InstallationResult } from "@/lib/types"
import { cn } from "@/lib/utils"
import { Progress } from "@/components/ui/progress"

interface PatchProgressProps {
  currentInstall: InstallationResult | null
  installQueue: PatchStatus[]
  completedInstalls: InstallationResult[]
  isPatching: boolean
}

export function PatchProgress({
  currentInstall,
  installQueue,
  completedInstalls,
  isPatching,
}: PatchProgressProps) {
  const totalItems = installQueue.length + completedInstalls.length
  const completedCount = completedInstalls.length
  const successCount = completedInstalls.filter((r) => r.status === "Success").length
  const failedCount = completedInstalls.filter((r) => r.status === "Failed").length
  const overallProgress = totalItems > 0 ? Math.round((completedCount / totalItems) * 100) : 0

  if (!isPatching && completedInstalls.length === 0) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="text-center">
          <RotateCw className="mx-auto h-16 w-16 text-muted-foreground" />
          <p className="mt-4 text-lg text-muted-foreground">No active patch cycle</p>
          <p className="mt-1 text-sm text-muted-foreground">
            Start a patch cycle from the Overview or Applications tab
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold text-foreground">Patch Progress</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {isPatching
            ? `Installing updates... ${completedCount} of ${totalItems} complete`
            : `Patch cycle complete. ${successCount} succeeded, ${failedCount} failed.`}
        </p>
      </div>

      {/* Overall Progress */}
      <div className="mb-8 rounded-lg border border-border bg-card p-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="font-semibold text-foreground">Overall Progress</h2>
          <span className="text-2xl font-bold text-primary">{overallProgress}%</span>
        </div>
        <Progress value={overallProgress} className="h-3" />
        <div className="mt-4 flex justify-between text-sm text-muted-foreground">
          <span>{completedCount} of {totalItems} applications</span>
          <span>
            <span className="text-green-400">{successCount} success</span>
            {failedCount > 0 && (
              <>
                {" "}/{" "}
                <span className="text-red-400">{failedCount} failed</span>
              </>
            )}
          </span>
        </div>
      </div>

      {/* Current Installation */}
      {currentInstall && (
        <div className="mb-6 rounded-lg border border-primary/50 bg-primary/5 p-4">
          <div className="mb-3 flex items-center gap-3">
            <Loader2 className="h-5 w-5 animate-spin text-primary" />
            <span className="font-semibold text-foreground">Installing: {currentInstall.appName}</span>
          </div>
          <Progress value={currentInstall.progress || 0} className="h-2" />
          <p className="mt-2 text-sm text-muted-foreground">{currentInstall.message}</p>
        </div>
      )}

      {/* Installation Queue */}
      <div className="rounded-lg border border-border bg-card">
        <div className="border-b border-border px-4 py-3">
          <h2 className="font-semibold text-foreground">Installation Queue</h2>
        </div>
        <div className="divide-y divide-border">
          {/* Completed Items */}
          {completedInstalls.map((result) => (
            <div
              key={result.appId}
              className="flex items-center justify-between px-4 py-3"
            >
              <div className="flex items-center gap-3">
                {result.status === "Success" ? (
                  <CheckCircle className="h-5 w-5 text-green-400" />
                ) : (
                  <XCircle className="h-5 w-5 text-red-400" />
                )}
                <div>
                  <p className="font-medium text-foreground">{result.appName}</p>
                  <p className="text-xs text-muted-foreground">{result.message}</p>
                </div>
              </div>
              <div className="flex items-center gap-3 text-sm">
                {result.rebootRequired && (
                  <span className="rounded bg-yellow-500/20 px-2 py-0.5 text-xs text-yellow-400">
                    Reboot Required
                  </span>
                )}
                <span className="text-muted-foreground">
                  {(result.duration / 1000).toFixed(1)}s
                </span>
                <span
                  className={cn(
                    "font-medium",
                    result.status === "Success" ? "text-green-400" : "text-red-400"
                  )}
                >
                  {result.status}
                </span>
              </div>
            </div>
          ))}

          {/* Current Item */}
          {currentInstall && (
            <div className="flex items-center justify-between bg-primary/5 px-4 py-3">
              <div className="flex items-center gap-3">
                <Loader2 className="h-5 w-5 animate-spin text-primary" />
                <div>
                  <p className="font-medium text-foreground">{currentInstall.appName}</p>
                  <p className="text-xs text-muted-foreground">
                    Installing... {currentInstall.progress}%
                  </p>
                </div>
              </div>
              <span className="text-sm font-medium text-primary">In Progress</span>
            </div>
          )}

          {/* Pending Items */}
          {installQueue
            .filter(
              (item) =>
                !completedInstalls.find((c) => c.appId === item.appId) &&
                (!currentInstall || currentInstall.appId !== item.appId)
            )
            .map((item) => (
              <div
                key={item.appId}
                className="flex items-center justify-between px-4 py-3 opacity-60"
              >
                <div className="flex items-center gap-3">
                  <Clock className="h-5 w-5 text-muted-foreground" />
                  <div>
                    <p className="font-medium text-foreground">{item.appName}</p>
                    <p className="text-xs text-muted-foreground">
                      {item.installedVersion} → {item.availableVersion}
                    </p>
                  </div>
                </div>
                <span className="text-sm text-muted-foreground">Pending</span>
              </div>
            ))}
        </div>
      </div>

      {/* Summary when complete */}
      {!isPatching && completedInstalls.length > 0 && (
        <div className="mt-6 rounded-lg border border-border bg-card p-4">
          <h3 className="mb-3 font-semibold text-foreground">Summary</h3>
          <div className="grid grid-cols-3 gap-4 text-center">
            <div>
              <p className="text-2xl font-bold text-green-400">{successCount}</p>
              <p className="text-sm text-muted-foreground">Successful</p>
            </div>
            <div>
              <p className="text-2xl font-bold text-red-400">{failedCount}</p>
              <p className="text-sm text-muted-foreground">Failed</p>
            </div>
            <div>
              <p className="text-2xl font-bold text-yellow-400">
                {completedInstalls.filter((r) => r.rebootRequired).length}
              </p>
              <p className="text-sm text-muted-foreground">Reboot Required</p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
