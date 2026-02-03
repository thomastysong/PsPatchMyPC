"use client"

import { Minus, Square, X } from "lucide-react"

interface TitleBarProps {
  pendingUpdates: number
}

export function TitleBar({ pendingUpdates }: TitleBarProps) {
  return (
    <header className="flex h-10 items-center justify-between border-b border-border bg-card px-3">
      <div className="flex items-center gap-3">
        <div className="flex h-6 w-6 items-center justify-center rounded bg-primary">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            className="h-4 w-4 text-primary-foreground"
            stroke="currentColor"
            strokeWidth="2"
          >
            <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
          </svg>
        </div>
        <span className="text-sm font-medium text-foreground">PsPatchMyPC</span>
        {pendingUpdates > 0 && (
          <span className="rounded bg-primary/20 px-2 py-0.5 text-xs font-medium text-primary">
            {pendingUpdates} update{pendingUpdates !== 1 ? "s" : ""} available
          </span>
        )}
      </div>
      
      <div className="flex items-center">
        <button
          className="flex h-10 w-12 items-center justify-center text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          aria-label="Minimize"
        >
          <Minus className="h-4 w-4" />
        </button>
        <button
          className="flex h-10 w-12 items-center justify-center text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          aria-label="Maximize"
        >
          <Square className="h-3 w-3" />
        </button>
        <button
          className="flex h-10 w-12 items-center justify-center text-muted-foreground transition-colors hover:bg-destructive hover:text-destructive-foreground"
          aria-label="Close"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </header>
  )
}
