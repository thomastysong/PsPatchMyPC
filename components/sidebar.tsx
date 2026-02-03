"use client"

import { LayoutDashboard, Package, RefreshCw, FileText, Settings, Loader2 } from "lucide-react"
import type { ViewMode } from "./patch-manager-client"
import { cn } from "@/lib/utils"

interface SidebarProps {
  currentView: ViewMode
  onViewChange: (view: ViewMode) => void
  pendingUpdates: number
  isPatching: boolean
}

const navItems: { id: ViewMode; label: string; icon: typeof LayoutDashboard }[] = [
  { id: "overview", label: "Overview", icon: LayoutDashboard },
  { id: "applications", label: "Applications", icon: Package },
  { id: "progress", label: "Progress", icon: RefreshCw },
  { id: "logs", label: "Activity Log", icon: FileText },
  { id: "settings", label: "Settings", icon: Settings },
]

export function Sidebar({ currentView, onViewChange, pendingUpdates, isPatching }: SidebarProps) {
  return (
    <aside className="flex w-56 flex-col border-r border-border bg-card">
      <nav className="flex-1 p-2">
        <ul className="space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon
            const isActive = currentView === item.id
            const showBadge = item.id === "applications" && pendingUpdates > 0
            const showSpinner = item.id === "progress" && isPatching

            return (
              <li key={item.id}>
                <button
                  onClick={() => onViewChange(item.id)}
                  className={cn(
                    "flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary/10 text-primary"
                      : "text-muted-foreground hover:bg-muted hover:text-foreground"
                  )}
                >
                  {showSpinner ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Icon className="h-4 w-4" />
                  )}
                  <span className="flex-1 text-left">{item.label}</span>
                  {showBadge && (
                    <span className="flex h-5 min-w-[20px] items-center justify-center rounded-full bg-primary px-1.5 text-xs font-semibold text-primary-foreground">
                      {pendingUpdates}
                    </span>
                  )}
                </button>
              </li>
            )
          })}
        </ul>
      </nav>

      <div className="border-t border-border p-4">
        <div className="text-xs text-muted-foreground">
          <div className="flex items-center justify-between">
            <span>Engine:</span>
            <span className="font-medium text-foreground">winget</span>
          </div>
          <div className="mt-1 flex items-center justify-between">
            <span>Version:</span>
            <span className="font-medium text-foreground">1.0.0</span>
          </div>
        </div>
      </div>
    </aside>
  )
}
