"use client"

import { AlertCircle, AlertTriangle, CheckCircle, Info } from "lucide-react"
import { cn } from "../lib/utils"

interface LogEntry {
  id: string
  timestamp: string
  type: "info" | "warning" | "error" | "success"
  message: string
  appId?: string
}

interface ActivityLogProps {
  logs: LogEntry[]
}

const typeConfig = {
  info: {
    icon: Info,
    color: "text-primary",
    bg: "bg-primary/10",
  },
  warning: {
    icon: AlertTriangle,
    color: "text-yellow-400",
    bg: "bg-yellow-400/10",
  },
  error: {
    icon: AlertCircle,
    color: "text-red-400",
    bg: "bg-red-400/10",
  },
  success: {
    icon: CheckCircle,
    color: "text-green-400",
    bg: "bg-green-400/10",
  },
}

export function ActivityLog({ logs }: ActivityLogProps) {
  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold text-foreground">Activity Log</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Recent patch management activity
        </p>
      </div>

      <div className="rounded-lg border border-border bg-card">
        {logs.length === 0 ? (
          <div className="p-8 text-center">
            <Info className="mx-auto h-12 w-12 text-muted-foreground" />
            <p className="mt-4 text-muted-foreground">No activity yet</p>
          </div>
        ) : (
          <div className="divide-y divide-border">
            {logs.map((log) => {
              const config = typeConfig[log.type]
              const Icon = config.icon

              return (
                <div key={log.id} className="flex items-start gap-3 px-4 py-3">
                  <div className={cn("mt-0.5 rounded p-1", config.bg)}>
                    <Icon className={cn("h-4 w-4", config.color)} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm text-foreground">{log.message}</p>
                    <div className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
                      <span>{new Date(log.timestamp).toLocaleString()}</span>
                      {log.appId && (
                        <>
                          <span>•</span>
                          <span className="font-mono">{log.appId}</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
