"use client"

import { useEffect, useState, useCallback, use } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { apiClient, GenerationDetail, GenerationStatus } from "@/lib/api-client"

type PageProps = {
  params: Promise<{ id: string }>
}

const STATUS_LABELS: Record<GenerationStatus, string> = {
  PENDING: "Queued",
  QUEUED: "Starting...",
  SCRIPT_GEN: "Generating Scripts",
  AVATAR_GEN: "Creating Avatars",
  VIDEO_GEN: "Rendering Videos",
  COMPOSITING: "Compositing",
  UPLOADING: "Uploading",
  COMPLETED: "Completed",
  FAILED: "Failed",
}

const STATUS_ORDER: GenerationStatus[] = [
  "PENDING",
  "QUEUED",
  "SCRIPT_GEN",
  "AVATAR_GEN",
  "VIDEO_GEN",
  "COMPOSITING",
  "UPLOADING",
  "COMPLETED",
]

function getStatusProgress(status: GenerationStatus): number {
  const index = STATUS_ORDER.indexOf(status)
  if (status === "FAILED") return 100
  if (index === -1) return 0
  return Math.round((index / (STATUS_ORDER.length - 1)) * 100)
}

export default function GenerationProgressPage({ params }: PageProps) {
  const resolvedParams = use(params)
  const router = useRouter()
  const [generation, setGeneration] = useState<GenerationDetail | null>(null)
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading")
  const [error, setError] = useState<string | null>(null)

  const loadGeneration = useCallback(async () => {
    try {
      const response = await apiClient.generations.get(resolvedParams.id)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to load generation")
      }
      setGeneration(response.data)
      setStatus("success")
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load")
      setStatus("error")
    }
  }, [resolvedParams.id])

  useEffect(() => {
    loadGeneration()
  }, [loadGeneration])

  // Poll for updates if generation is in progress
  useEffect(() => {
    if (!generation) return
    if (generation.status === "COMPLETED" || generation.status === "FAILED") return

    const interval = setInterval(loadGeneration, 5000)
    return () => clearInterval(interval)
  }, [generation, loadGeneration])

  if (status === "loading") {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p>Loading generation...</p>
      </div>
    )
  }

  if (status === "error" || !generation) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <p className="text-destructive mb-4">Error: {error}</p>
          <button onClick={loadGeneration} className="underline">
            Retry
          </button>
        </div>
      </div>
    )
  }

  const isInProgress =
    generation.status !== "COMPLETED" && generation.status !== "FAILED"
  const progress = getStatusProgress(generation.status)

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="container mx-auto px-4 py-4">
          <Link
            href={`/briefs/${generation.briefId}`}
            className="text-sm text-muted-foreground hover:underline"
          >
            ← Back to Brief
          </Link>
        </div>
      </header>

      <main className="container mx-auto px-4 py-6 max-w-3xl">
        {/* Status Card */}
        <section className="bg-card rounded-lg border p-6 mb-6">
          <div className="flex items-center justify-between mb-4">
            <h1 className="text-2xl font-bold">Video Generation</h1>
            <span
              className={`px-3 py-1 rounded-full text-sm font-medium ${
                generation.status === "COMPLETED"
                  ? "bg-green-100 text-green-800"
                  : generation.status === "FAILED"
                    ? "bg-red-100 text-red-800"
                    : "bg-blue-100 text-blue-800"
              }`}
            >
              {STATUS_LABELS[generation.status]}
            </span>
          </div>

          {/* Progress Bar */}
          <div className="mb-4">
            <div className="flex justify-between text-sm text-muted-foreground mb-2">
              <span>Progress</span>
              <span>{progress}%</span>
            </div>
            <div className="h-3 bg-muted rounded-full overflow-hidden">
              <div
                className={`h-full transition-all duration-500 ${
                  generation.status === "FAILED" ? "bg-red-500" : "bg-primary"
                }`}
                style={{ width: `${progress}%` }}
              />
            </div>
          </div>

          {/* Stage Indicators */}
          <div className="flex justify-between text-xs text-muted-foreground">
            {STATUS_ORDER.slice(0, -1).map((s) => {
              const currentIndex = STATUS_ORDER.indexOf(generation.status)
              const stageIndex = STATUS_ORDER.indexOf(s)
              const isActive = stageIndex <= currentIndex
              const isCurrent = s === generation.status

              return (
                <div
                  key={s}
                  className={`flex flex-col items-center ${
                    isCurrent ? "text-primary font-medium" : isActive ? "text-foreground" : ""
                  }`}
                >
                  <div
                    className={`w-3 h-3 rounded-full mb-1 ${
                      isCurrent
                        ? "bg-primary animate-pulse"
                        : isActive
                          ? "bg-primary"
                          : "bg-muted"
                    }`}
                  />
                  <span className="hidden sm:block">{STATUS_LABELS[s]}</span>
                </div>
              )
            })}
          </div>

          {/* Loading indicator */}
          {isInProgress && (
            <div className="mt-4 flex items-center justify-center gap-2 text-muted-foreground">
              <div className="animate-spin h-4 w-4 border-2 border-primary border-t-transparent rounded-full" />
              <span>Processing... Polling every 5 seconds</span>
            </div>
          )}
        </section>

        {/* Video Progress */}
        <section className="bg-card rounded-lg border p-6 mb-6">
          <h2 className="text-lg font-semibold mb-4">Videos</h2>

          <div className="grid grid-cols-3 gap-4 text-center mb-4">
            <div className="p-3 bg-muted rounded">
              <p className="text-2xl font-bold text-green-600">
                {generation.progress.completed}
              </p>
              <p className="text-sm text-muted-foreground">Completed</p>
            </div>
            <div className="p-3 bg-muted rounded">
              <p className="text-2xl font-bold text-yellow-600">
                {generation.progress.pending}
              </p>
              <p className="text-sm text-muted-foreground">Pending</p>
            </div>
            <div className="p-3 bg-muted rounded">
              <p className="text-2xl font-bold text-red-600">
                {generation.progress.failed}
              </p>
              <p className="text-sm text-muted-foreground">Failed</p>
            </div>
          </div>

          <p className="text-center text-muted-foreground">
            {generation.progress.completed} of {generation.targetCount} videos completed
          </p>
        </section>

        {/* Cost Summary */}
        <section className="bg-card rounded-lg border p-6 mb-6">
          <h2 className="text-lg font-semibold mb-4">Cost</h2>
          <p className="text-3xl font-bold">${generation.totalCost}</p>
          <p className="text-sm text-muted-foreground">
            {generation.progress.completed > 0
              ? `~$${(parseFloat(generation.totalCost) / generation.progress.completed).toFixed(4)} per video`
              : "Calculating..."}
          </p>
        </section>

        {/* Video List */}
        {generation.videos.length > 0 && (
          <section className="bg-card rounded-lg border p-6">
            <h2 className="text-lg font-semibold mb-4">Generated Videos</h2>
            <div className="space-y-3">
              {generation.videos.map((video, index) => (
                <div
                  key={video.id}
                  className="flex items-center justify-between p-3 bg-muted rounded"
                >
                  <div className="flex items-center gap-3">
                    <span className="text-sm text-muted-foreground">#{index + 1}</span>
                    <div>
                      <p className="font-medium text-sm">{video.id.slice(0, 8)}...</p>
                      <p className="text-xs text-muted-foreground">${video.totalCost}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`px-2 py-1 text-xs rounded ${
                        video.status === "COMPLETED"
                          ? "bg-green-100 text-green-800"
                          : video.status === "FAILED"
                            ? "bg-red-100 text-red-800"
                            : "bg-yellow-100 text-yellow-800"
                      }`}
                    >
                      {video.status}
                    </span>
                    {video.videoUrl && (
                      <Link
                        href={video.videoUrl}
                        target="_blank"
                        className="text-xs text-primary hover:underline"
                      >
                        View
                      </Link>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {/* Actions */}
        <div className="mt-6 flex gap-4">
          {generation.status === "COMPLETED" && (
            <button
              onClick={() => router.push("/videos")}
              className="flex-1 px-4 py-2 bg-primary text-primary-foreground rounded hover:bg-primary/90"
            >
              View All Videos
            </button>
          )}
          {generation.status === "FAILED" && (
            <Link
              href={`/briefs/${generation.briefId}`}
              className="flex-1 px-4 py-2 bg-primary text-primary-foreground rounded hover:bg-primary/90 text-center"
            >
              Edit Brief & Retry
            </Link>
          )}
          <Link
            href={`/briefs/${generation.briefId}`}
            className="flex-1 px-4 py-2 border rounded hover:bg-muted text-center"
          >
            Back to Brief
          </Link>
        </div>
      </main>
    </div>
  )
}
