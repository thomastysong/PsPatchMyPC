"use client"

import { useState } from "react"
import { Play, Clock, AlertCircle, CheckCircle, ChevronRight, Search } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import type { PatchStatus } from "@/lib/types"
import { getPriorityColor, getPhaseColor } from "@/lib/mock-data"
import { cn } from "@/lib/utils"

interface ApplicationListProps {
  patchStatuses: PatchStatus[]
  isPatching: boolean
  onInstall: (appId: string) => void
  onDefer: (appId: string) => void
}

export function ApplicationList({
  patchStatuses,
  isPatching,
  onInstall,
  onDefer,
}: ApplicationListProps) {
  const [searchQuery, setSearchQuery] = useState("")
  const [selectedApp, setSelectedApp] = useState<string | null>(null)

  const filteredStatuses = patchStatuses.filter(
    (status) =>
      status.appName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      status.appId.toLowerCase().includes(searchQuery.toLowerCase())
  )

  const selectedStatus = patchStatuses.find((s) => s.appId === selectedApp)

  return (
    <div className="flex h-full">
      {/* Application List */}
      <div className="w-96 border-r border-border">
        <div className="border-b border-border p-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              type="text"
              placeholder="Search applications..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
          </div>
        </div>
        <div className="overflow-auto">
          {filteredStatuses.map((status) => {
            const isSelected = selectedApp === status.appId
            const canDefer =
              status.deferralState &&
              status.deferralState.phase !== "Elapsed" &&
              status.deferralState.deferralCount < status.deferralState.maxDeferrals

            return (
              <button
                key={status.appId}
                onClick={() => setSelectedApp(status.appId)}
                className={cn(
                  "flex w-full items-center gap-3 border-b border-border px-4 py-3 text-left transition-colors",
                  isSelected ? "bg-primary/10" : "hover:bg-muted"
                )}
              >
                <div className="flex h-10 w-10 items-center justify-center rounded bg-muted text-sm font-semibold text-muted-foreground">
                  {status.appName.charAt(0)}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="truncate font-medium text-foreground">{status.appName}</span>
                    {status.updateAvailable ? (
                      <span className="h-2 w-2 rounded-full bg-primary" />
                    ) : (
                      <CheckCircle className="h-3.5 w-3.5 text-green-400" />
                    )}
                  </div>
                  <div className="flex items-center gap-2 text-xs text-muted-foreground">
                    <span className={getPriorityColor(status.priority)}>{status.priority}</span>
                    <span>•</span>
                    <span>{status.installedVersion}</span>
                    {status.updateAvailable && (
                      <>
                        <span>→</span>
                        <span className="text-primary">{status.availableVersion}</span>
                      </>
                    )}
                  </div>
                </div>
                <ChevronRight className="h-4 w-4 text-muted-foreground" />
              </button>
            )
          })}
        </div>
      </div>

      {/* Detail Panel */}
      <div className="flex-1 overflow-auto">
        {selectedStatus ? (
          <div className="p-6">
            <div className="mb-6 flex items-start justify-between">
              <div>
                <h2 className="text-2xl font-semibold text-foreground">{selectedStatus.appName}</h2>
                <p className="mt-1 text-sm text-muted-foreground">{selectedStatus.appId}</p>
              </div>
              {selectedStatus.updateAvailable && (
                <div className="flex gap-2">
                  {selectedStatus.deferralState &&
                    selectedStatus.deferralState.phase !== "Elapsed" &&
                    selectedStatus.deferralState.deferralCount <
                      selectedStatus.deferralState.maxDeferrals && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => onDefer(selectedStatus.appId)}
                        disabled={isPatching}
                        className="gap-2"
                      >
                        <Clock className="h-4 w-4" />
                        Defer
                      </Button>
                    )}
                  <Button
                    size="sm"
                    onClick={() => onInstall(selectedStatus.appId)}
                    disabled={isPatching}
                    className="gap-2"
                  >
                    <Play className="h-4 w-4" />
                    Install Now
                  </Button>
                </div>
              )}
            </div>

            {/* Version Info */}
            <div className="mb-6 grid grid-cols-2 gap-4">
              <div className="rounded-lg border border-border bg-card p-4">
                <p className="text-sm text-muted-foreground">Installed Version</p>
                <p className="mt-1 font-mono text-lg text-foreground">
                  {selectedStatus.installedVersion}
                </p>
              </div>
              <div className="rounded-lg border border-border bg-card p-4">
                <p className="text-sm text-muted-foreground">Available Version</p>
                <p
                  className={cn(
                    "mt-1 font-mono text-lg",
                    selectedStatus.updateAvailable ? "text-primary" : "text-foreground"
                  )}
                >
                  {selectedStatus.updateAvailable
                    ? selectedStatus.availableVersion
                    : selectedStatus.installedVersion}
                </p>
              </div>
            </div>

            {/* Status */}
            <div className="mb-6 rounded-lg border border-border bg-card p-4">
              <h3 className="mb-3 font-semibold text-foreground">Status</h3>
              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">Priority</span>
                  <span className={getPriorityColor(selectedStatus.priority)}>
                    {selectedStatus.priority}
                  </span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">Update Available</span>
                  <span className={selectedStatus.updateAvailable ? "text-primary" : "text-green-400"}>
                    {selectedStatus.updateAvailable ? "Yes" : "No"}
                  </span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">Conflicting Processes</span>
                  <span
                    className={selectedStatus.processesRunning ? "text-yellow-400" : "text-foreground"}
                  >
                    {selectedStatus.processesRunning
                      ? `Running (${selectedStatus.conflictingProcesses.join(", ")})`
                      : "None"}
                  </span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">Last Checked</span>
                  <span className="text-foreground">
                    {new Date(selectedStatus.lastChecked).toLocaleString()}
                  </span>
                </div>
              </div>
            </div>

            {/* Deferral State */}
            {selectedStatus.deferralState && selectedStatus.updateAvailable && (
              <div className="rounded-lg border border-border bg-card p-4">
                <h3 className="mb-3 font-semibold text-foreground">Deferral Information</h3>
                <div className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Phase</span>
                    <span
                      className={`rounded border px-2 py-0.5 text-xs ${getPhaseColor(
                        selectedStatus.deferralState.phase
                      )}`}
                    >
                      {selectedStatus.deferralState.phase}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Deferrals Used</span>
                    <span className="text-foreground">
                      {selectedStatus.deferralState.deferralCount} /{" "}
                      {selectedStatus.deferralState.maxDeferrals}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Deadline</span>
                    <span
                      className={cn(
                        "text-foreground",
                        selectedStatus.deferralState.phase === "Elapsed" && "text-red-400"
                      )}
                    >
                      {new Date(selectedStatus.deferralState.deadlineDate).toLocaleString()}
                    </span>
                  </div>
                  {selectedStatus.deferralState.lastDeferral && (
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Last Deferred</span>
                      <span className="text-foreground">
                        {new Date(selectedStatus.deferralState.lastDeferral).toLocaleString()}
                      </span>
                    </div>
                  )}
                </div>

                {/* Deferral Progress Bar */}
                <div className="mt-4">
                  <div className="mb-1 flex justify-between text-xs text-muted-foreground">
                    <span>Deferrals remaining</span>
                    <span>
                      {selectedStatus.deferralState.maxDeferrals -
                        selectedStatus.deferralState.deferralCount}{" "}
                      left
                    </span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-muted">
                    <div
                      className={cn(
                        "h-full rounded-full transition-all",
                        selectedStatus.deferralState.phase === "Elapsed"
                          ? "bg-red-500"
                          : selectedStatus.deferralState.phase === "Imminent"
                          ? "bg-orange-500"
                          : "bg-primary"
                      )}
                      style={{
                        width: `${
                          ((selectedStatus.deferralState.maxDeferrals -
                            selectedStatus.deferralState.deferralCount) /
                            selectedStatus.deferralState.maxDeferrals) *
                          100
                        }%`,
                      }}
                    />
                  </div>
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="flex h-full items-center justify-center">
            <div className="text-center">
              <AlertCircle className="mx-auto h-12 w-12 text-muted-foreground" />
              <p className="mt-4 text-muted-foreground">Select an application to view details</p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
