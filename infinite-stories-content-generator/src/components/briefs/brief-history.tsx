"use client"

import type { BriefWithGenerations } from "@/lib/api-client"

type BriefHistoryProps = {
  brief: BriefWithGenerations
}

type TimelineEvent = {
  type: "created" | "parsed" | "generation" | "updated"
  date: Date
  label: string
  detail?: string
}

export function BriefHistory({ brief }: BriefHistoryProps) {
  const events: TimelineEvent[] = []

  // Created event
  events.push({
    type: "created",
    date: new Date(brief.createdAt),
    label: "Brief Created",
  })

  // Parsed event (if different from created and status is PARSED)
  if (brief.status === "PARSED" && brief.updatedAt !== brief.createdAt) {
    events.push({
      type: "parsed",
      date: new Date(brief.updatedAt),
      label: "Brief Parsed",
      detail: brief.parsedData?.hook,
    })
  }

  // Generation events
  if (brief.generations) {
    for (const gen of brief.generations) {
      events.push({
        type: "generation",
        date: new Date(gen.createdAt),
        label: `Generation Started`,
        detail: `${gen.targetCount} videos - ${gen.status}`,
      })
    }
  }

  // Sort by date descending
  events.sort((a, b) => b.date.getTime() - a.date.getTime())

  const getEventIcon = (type: TimelineEvent["type"]) => {
    switch (type) {
      case "created":
        return "●"
      case "parsed":
        return "◆"
      case "generation":
        return "▶"
      case "updated":
        return "◇"
      default:
        return "○"
    }
  }

  const getEventColor = (type: TimelineEvent["type"]) => {
    switch (type) {
      case "created":
        return "text-blue-500"
      case "parsed":
        return "text-green-500"
      case "generation":
        return "text-purple-500"
      case "updated":
        return "text-yellow-500"
      default:
        return "text-muted-foreground"
    }
  }

  return (
    <div className="space-y-4">
      {events.map((event, i) => (
        <div key={i} className="flex gap-3">
          <div className={`mt-1 ${getEventColor(event.type)}`}>
            {getEventIcon(event.type)}
          </div>
          <div className="flex-1 min-w-0">
            <p className="font-medium text-sm">{event.label}</p>
            {event.detail && (
              <p className="text-xs text-muted-foreground truncate">{event.detail}</p>
            )}
            <p className="text-xs text-muted-foreground">
              {event.date.toLocaleString()}
            </p>
          </div>
        </div>
      ))}

      {events.length === 0 && (
        <p className="text-sm text-muted-foreground">No history available</p>
      )}
    </div>
  )
}
