"use client"

import { RefreshCw, Play, AlertTriangle, CheckCircle, Clock, AlertCircle, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import type { PatchStatus } from "@/lib/types"
import { getPhaseColor } from "@/lib/mock-data"

interface StatusOverviewProps {
  patchStatuses: PatchStatus[]
  isScanning: boolean
  isPatching: boolean
  onScan: () => void
  onInstallAll: () => void
}

export function StatusOverview({
  patchStatuses,
  isScanning,
  isPatching,
  onScan,
  onInstallAll,
}: StatusOverviewProps) {
  const pendingUpdates = patchStatuses.filter((s) => s.updateAvailable)
  const criticalCount = pendingUpdates.filter((s) => s.priority === "Critical").length
  const highCount = pendingUpdates.filter((s) => s.priority === "High").length
  const elapsedCount = pendingUpdates.filter((s) => s.deferralState?.phase === "Elapsed").length
  const imminentCount = pendingUpdates.filter((s) => s.deferralState?.phase === "Imminent").length
  const upToDate = pendingUpdates.length === 0 && patchStatuses.length > 0

  return (
    <div className="p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Patch Status</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Enterprise application patching with progressive enforcement
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button
            variant="outline"
            size="sm"
            onClick={onScan}
            disabled={isScanning || isPatching}
            className="gap-2"
          >
            {isScanning ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <RefreshCw className="h-4 w-4" />
            )}
            {isScanning ? "Scanning..." : "Check for Updates"}
          </Button>
          <Button
            size="sm"
            onClick={onInstallAll}
            disabled={pendingUpdates.length === 0 || isPatching || isScanning}
            className="gap-2"
          >
            {isPatching ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Play className="h-4 w-4" />
            )}
            {isPatching ? "Installing..." : "Install All Updates"}
          </Button>
        </div>
      </div>

      {/* Status Cards */}
      <div className="mb-8 grid grid-cols-4 gap-4">
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
              <Clock className="h-5 w-5 text-primary" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">{pendingUpdates.length}</p>
              <p className="text-sm text-muted-foreground">Pending Updates</p>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-orange-500/10">
              <AlertTriangle className="h-5 w-5 text-orange-400" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">{criticalCount + highCount}</p>
              <p className="text-sm text-muted-foreground">High Priority</p>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-red-500/10">
              <AlertCircle className="h-5 w-5 text-red-400" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">{elapsedCount}</p>
              <p className="text-sm text-muted-foreground">Past Deadline</p>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-green-500/10">
              <CheckCircle className="h-5 w-5 text-green-400" />
            </div>
            <div>
              <p className="text-2xl font-bold text-foreground">
                {patchStatuses.length - pendingUpdates.length}
              </p>
              <p className="text-sm text-muted-foreground">Up to Date</p>
            </div>
          </div>
        </div>
      </div>

      {/* Compliance Status */}
      <div className="rounded-lg border border-border bg-card p-6">
        <h2 className="mb-4 text-lg font-semibold text-foreground">Compliance Status</h2>
        
        {upToDate ? (
          <div className="flex items-center gap-3 rounded-lg bg-green-500/10 p-4">
            <CheckCircle className="h-6 w-6 text-green-400" />
            <div>
              <p className="font-medium text-green-400">All applications are up to date</p>
              <p className="text-sm text-muted-foreground">
                No pending updates found for managed applications
              </p>
            </div>
          </div>
        ) : (
          <>
            {elapsedCount > 0 && (
              <div className="mb-3 flex items-center gap-3 rounded-lg bg-red-500/10 p-4">
                <AlertCircle className="h-6 w-6 text-red-400" />
                <div>
                  <p className="font-medium text-red-400">
                    {elapsedCount} application{elapsedCount !== 1 ? "s" : ""} past deadline
                  </p>
                  <p className="text-sm text-muted-foreground">
                    These updates must be installed immediately
                  </p>
                </div>
              </div>
            )}
            
            {imminentCount > 0 && (
              <div className="mb-3 flex items-center gap-3 rounded-lg bg-orange-500/10 p-4">
                <AlertTriangle className="h-6 w-6 text-orange-400" />
                <div>
                  <p className="font-medium text-orange-400">
                    {imminentCount} application{imminentCount !== 1 ? "s" : ""} approaching deadline
                  </p>
                  <p className="text-sm text-muted-foreground">
                    Limited deferral options available
                  </p>
                </div>
              </div>
            )}

            {pendingUpdates.length > 0 && elapsedCount === 0 && imminentCount === 0 && (
              <div className="flex items-center gap-3 rounded-lg bg-primary/10 p-4">
                <Clock className="h-6 w-6 text-primary" />
                <div>
                  <p className="font-medium text-primary">
                    {pendingUpdates.length} update{pendingUpdates.length !== 1 ? "s" : ""} available
                  </p>
                  <p className="text-sm text-muted-foreground">
                    Review and install updates at your convenience
                  </p>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* Quick View of Pending Updates */}
      {pendingUpdates.length > 0 && (
        <div className="mt-6 rounded-lg border border-border bg-card">
          <div className="border-b border-border px-4 py-3">
            <h2 className="font-semibold text-foreground">Pending Updates</h2>
          </div>
          <div className="divide-y divide-border">
            {pendingUpdates.slice(0, 5).map((status) => (
              <div key={status.appId} className="flex items-center justify-between px-4 py-3">
                <div className="flex items-center gap-3">
                  <div className="flex h-8 w-8 items-center justify-center rounded bg-muted text-xs font-medium text-muted-foreground">
                    {status.appName.charAt(0)}
                  </div>
                  <div>
                    <p className="font-medium text-foreground">{status.appName}</p>
                    <p className="text-xs text-muted-foreground">
                      {status.installedVersion} → {status.availableVersion}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {status.processesRunning && (
                    <span className="rounded bg-yellow-500/20 px-2 py-0.5 text-xs text-yellow-400">
                      In Use
                    </span>
                  )}
                  {status.deferralState && (
                    <span
                      className={`rounded border px-2 py-0.5 text-xs ${getPhaseColor(
                        status.deferralState.phase
                      )}`}
                    >
                      {status.deferralState.phase}
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
          {pendingUpdates.length > 5 && (
            <div className="border-t border-border px-4 py-2 text-center">
              <span className="text-sm text-muted-foreground">
                +{pendingUpdates.length - 5} more update{pendingUpdates.length - 5 !== 1 ? "s" : ""}
              </span>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
