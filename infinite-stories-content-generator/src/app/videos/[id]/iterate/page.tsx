"use client"

import { useEffect, useState, useCallback, use } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { apiClient, VideoDetail } from "@/lib/api-client"

type PageProps = {
  params: Promise<{ id: string }>
}

export default function IterateOnWinnerPage({ params }: PageProps) {
  const resolvedParams = use(params)
  const router = useRouter()
  const [video, setVideo] = useState<VideoDetail | null>(null)
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading")
  const [error, setError] = useState<string | null>(null)
  const [isCreating, setIsCreating] = useState(false)

  // Variation options
  const [targetCount, setTargetCount] = useState(5)
  const [varyHook, setVaryHook] = useState(true)
  const [varyAvatar, setVaryAvatar] = useState(false)
  const [varyBroll, setVaryBroll] = useState(false)

  const loadVideo = useCallback(async () => {
    setStatus("loading")
    try {
      const response = await apiClient.videos.get(resolvedParams.id)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to load video")
      }

      // Check if video is approved
      if (response.data.qualityStatus !== "PASSED") {
        throw new Error("Only approved videos can be used for iteration")
      }

      setVideo(response.data)
      setStatus("success")
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load")
      setStatus("error")
    }
  }, [resolvedParams.id])

  useEffect(() => {
    loadVideo()
  }, [loadVideo])

  const handleIterate = async () => {
    setIsCreating(true)
    try {
      const response = await fetch(`/api/videos/${resolvedParams.id}/iterate`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${localStorage.getItem("admin_token") ?? ""}`,
        },
        body: JSON.stringify({
          targetCount,
          variationParams: {
            varyHook,
            varyAvatar,
            varyBroll,
          },
        }),
      })

      const data = await response.json()

      if (data.error || !data.data) {
        throw new Error(data.error?.message ?? "Failed to create iteration")
      }

      router.push(`/generations/${data.data.id}`)
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to create iteration")
    } finally {
      setIsCreating(false)
    }
  }

  if (status === "loading") {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p>Loading video...</p>
      </div>
    )
  }

  if (status === "error" || !video) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <p className="text-destructive mb-4">Error: {error}</p>
          <Link href="/videos" className="underline">
            Back to Videos
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="container mx-auto px-4 py-4">
          <Link
            href={`/videos/${resolvedParams.id}`}
            className="text-sm text-muted-foreground hover:underline"
          >
            ← Back to Video
          </Link>
        </div>
      </header>

      <main className="container mx-auto px-4 py-6 max-w-2xl">
        <h1 className="text-2xl font-bold mb-6">Iterate on Winner</h1>

        {/* Source Video Preview */}
        <section className="bg-card rounded-lg border p-6 mb-6">
          <h2 className="text-lg font-semibold mb-4">Source Video</h2>
          <div className="flex gap-4">
            <div className="w-24 h-40 bg-muted rounded overflow-hidden flex-shrink-0">
              {video.videoUrl && (
                <video src={video.videoUrl} className="w-full h-full object-cover" />
              )}
            </div>
            <div className="flex-1">
              <p className="text-sm text-muted-foreground mb-2">
                ID: {video.id.slice(0, 8)}...
              </p>
              {video.generationParams.script && (
                <>
                  <p className="text-sm font-medium mb-1">Hook:</p>
                  <p className="text-sm text-muted-foreground mb-2">
                    {video.generationParams.script.hook}
                  </p>
                </>
              )}
              <span className="px-2 py-1 text-xs bg-green-100 text-green-800 rounded">
                {video.qualityStatus}
              </span>
            </div>
          </div>
        </section>

        {/* Variation Options */}
        <section className="bg-card rounded-lg border p-6 mb-6">
          <h2 className="text-lg font-semibold mb-4">Variation Options</h2>
          <p className="text-sm text-muted-foreground mb-4">
            Select what to vary in the new videos. Unselected elements will remain
            similar to the source video.
          </p>

          <div className="space-y-4">
            <label className="flex items-start gap-3">
              <input
                type="checkbox"
                checked={varyHook}
                onChange={(e) => setVaryHook(e.target.checked)}
                className="mt-1 rounded"
              />
              <div>
                <p className="font-medium">Vary Hook</p>
                <p className="text-sm text-muted-foreground">
                  Generate different attention-grabbing openings while maintaining the
                  core message
                </p>
              </div>
            </label>

            <label className="flex items-start gap-3">
              <input
                type="checkbox"
                checked={varyAvatar}
                onChange={(e) => setVaryAvatar(e.target.checked)}
                className="mt-1 rounded"
              />
              <div>
                <p className="font-medium">Vary Avatar</p>
                <p className="text-sm text-muted-foreground">
                  Use different avatar personas within the same demographic constraints
                </p>
              </div>
            </label>

            <label className="flex items-start gap-3">
              <input
                type="checkbox"
                checked={varyBroll}
                onChange={(e) => setVaryBroll(e.target.checked)}
                className="mt-1 rounded"
              />
              <div>
                <p className="font-medium">Vary B-Roll</p>
                <p className="text-sm text-muted-foreground">
                  Use alternative matching scenes from the content library
                </p>
              </div>
            </label>
          </div>
        </section>

        {/* Target Count */}
        <section className="bg-card rounded-lg border p-6 mb-6">
          <h2 className="text-lg font-semibold mb-4">Number of Variations</h2>
          <div className="flex items-center gap-4">
            <input
              type="range"
              min={1}
              max={10}
              value={targetCount}
              onChange={(e) => setTargetCount(parseInt(e.target.value))}
              className="flex-1"
            />
            <span className="text-2xl font-bold w-12 text-center">{targetCount}</span>
          </div>
          <p className="text-sm text-muted-foreground mt-2">
            Generate {targetCount} new video{targetCount !== 1 ? "s" : ""} based on this
            winner
          </p>
        </section>

        {/* Estimated Cost */}
        <section className="bg-card rounded-lg border p-6 mb-6">
          <h2 className="text-lg font-semibold mb-2">Estimated Cost</h2>
          <p className="text-3xl font-bold">${(targetCount * 0.15).toFixed(2)}</p>
          <p className="text-sm text-muted-foreground">
            Based on average cost per video
          </p>
        </section>

        {/* Actions */}
        <div className="flex gap-4">
          <button
            onClick={handleIterate}
            disabled={isCreating || (!varyHook && !varyAvatar && !varyBroll)}
            className="flex-1 px-4 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            {isCreating ? "Creating Variations..." : `Generate ${targetCount} Variations`}
          </button>
          <Link
            href={`/videos/${resolvedParams.id}`}
            className="px-4 py-3 border rounded-lg hover:bg-muted"
          >
            Cancel
          </Link>
        </div>

        {!varyHook && !varyAvatar && !varyBroll && (
          <p className="text-sm text-destructive mt-4 text-center">
            Please select at least one variation option
          </p>
        )}
      </main>
    </div>
  )
}
