"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { apiClient, CostStats } from "@/lib/api-client"

export default function CostsDashboardPage() {
  const [stats, setStats] = useState<CostStats | null>(null)
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading")
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    loadStats()
  }, [])

  const loadStats = async () => {
    setStatus("loading")
    try {
      const response = await apiClient.costs.stats("daily")
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to load stats")
      }
      setStats(response.data)
      setStatus("success")
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load")
      setStatus("error")
    }
  }

  if (status === "loading") {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p>Loading costs...</p>
      </div>
    )
  }

  if (status === "error" || !stats) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <p className="text-destructive mb-4">Error: {error}</p>
          <button onClick={loadStats} className="underline">
            Retry
          </button>
        </div>
      </div>
    )
  }

  // Calculate percentages for service type breakdown
  const totalServiceCost =
    parseFloat(stats.byServiceType.script) +
    parseFloat(stats.byServiceType.avatar) +
    parseFloat(stats.byServiceType.video) +
    parseFloat(stats.byServiceType.storage)

  const getPercentage = (value: string) => {
    if (totalServiceCost === 0) return 0
    return Math.round((parseFloat(value) / totalServiceCost) * 100)
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-bold">Cost Dashboard</h1>
            <Link href="/briefs" className="text-sm text-muted-foreground hover:underline">
              ← Back to Briefs
            </Link>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-6">
        {/* Summary Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-card rounded-lg border p-4">
            <p className="text-sm text-muted-foreground">Today</p>
            <p className="text-2xl font-bold">${parseFloat(stats.today).toFixed(2)}</p>
          </div>
          <div className="bg-card rounded-lg border p-4">
            <p className="text-sm text-muted-foreground">This Week</p>
            <p className="text-2xl font-bold">${parseFloat(stats.thisWeek).toFixed(2)}</p>
          </div>
          <div className="bg-card rounded-lg border p-4">
            <p className="text-sm text-muted-foreground">This Month</p>
            <p className="text-2xl font-bold">${parseFloat(stats.thisMonth).toFixed(2)}</p>
          </div>
          <div className="bg-card rounded-lg border p-4">
            <p className="text-sm text-muted-foreground">All Time</p>
            <p className="text-2xl font-bold">${parseFloat(stats.allTime).toFixed(2)}</p>
          </div>
        </div>

        {/* Service Type Breakdown */}
        <section className="bg-card rounded-lg border p-6 mb-8">
          <h2 className="text-lg font-semibold mb-4">Cost by Service Type (Last 30 Days)</h2>

          <div className="space-y-4">
            {[
              { label: "Script Generation", key: "script" as const, color: "bg-blue-500" },
              { label: "Avatar Generation", key: "avatar" as const, color: "bg-purple-500" },
              { label: "Video Composition", key: "video" as const, color: "bg-green-500" },
              { label: "Storage", key: "storage" as const, color: "bg-yellow-500" },
            ].map((item) => (
              <div key={item.key}>
                <div className="flex justify-between text-sm mb-1">
                  <span>{item.label}</span>
                  <span>
                    ${parseFloat(stats.byServiceType[item.key]).toFixed(4)} (
                    {getPercentage(stats.byServiceType[item.key])}%)
                  </span>
                </div>
                <div className="h-2 bg-muted rounded-full overflow-hidden">
                  <div
                    className={`h-full ${item.color}`}
                    style={{ width: `${getPercentage(stats.byServiceType[item.key])}%` }}
                  />
                </div>
              </div>
            ))}
          </div>

          <div className="mt-4 pt-4 border-t">
            <div className="flex justify-between font-medium">
              <span>Total (30 Days)</span>
              <span>${totalServiceCost.toFixed(4)}</span>
            </div>
          </div>
        </section>

        {/* Daily Trend */}
        {stats.daily.length > 0 && (
          <section className="bg-card rounded-lg border p-6">
            <h2 className="text-lg font-semibold mb-4">Daily Spending (Last 30 Days)</h2>

            <div className="space-y-2">
              {stats.daily.slice(0, 14).map((day) => (
                <div key={day.date} className="flex items-center gap-4">
                  <span className="text-sm text-muted-foreground w-24">{day.date}</span>
                  <div className="flex-1 h-4 bg-muted rounded overflow-hidden">
                    <div
                      className="h-full bg-primary"
                      style={{
                        width: `${Math.min(
                          100,
                          (parseFloat(day.totalCost) /
                            Math.max(
                              ...stats.daily.map((d) => parseFloat(d.totalCost) || 0.01)
                            )) *
                            100
                        )}%`,
                      }}
                    />
                  </div>
                  <span className="text-sm w-20 text-right">
                    ${parseFloat(day.totalCost).toFixed(4)}
                  </span>
                  <span className="text-xs text-muted-foreground w-16">
                    {day.videoCount} videos
                  </span>
                </div>
              ))}
            </div>

            {stats.daily.length > 14 && (
              <p className="text-sm text-muted-foreground mt-4 text-center">
                Showing last 14 days of {stats.daily.length} days
              </p>
            )}
          </section>
        )}
      </main>
    </div>
  )
}
