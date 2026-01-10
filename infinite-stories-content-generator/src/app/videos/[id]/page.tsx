"use client"

import { useEffect, useState, useCallback, use } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { apiClient, VideoDetail, VideoCosts } from "@/lib/api-client"

type PageProps = {
  params: Promise<{ id: string }>
}

export default function VideoDetailPage({ params }: PageProps) {
  const resolvedParams = use(params)
  const router = useRouter()
  const [video, setVideo] = useState<VideoDetail | null>(null)
  const [costs, setCosts] = useState<VideoCosts | null>(null)
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading")
  const [error, setError] = useState<string | null>(null)
  const [showCosts, setShowCosts] = useState(false)
  const [showFlag, setShowFlag] = useState(false)
  const [flagNote, setFlagNote] = useState("")
  const [isUpdating, setIsUpdating] = useState(false)

  const loadVideo = useCallback(async () => {
    setStatus("loading")
    try {
      const response = await apiClient.videos.get(resolvedParams.id)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to load video")
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

  const loadCosts = async () => {
    if (costs) {
      setShowCosts(!showCosts)
      return
    }

    try {
      const response = await apiClient.videos.getCosts(resolvedParams.id)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to load costs")
      }
      setCosts(response.data)
      setShowCosts(true)
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to load costs")
    }
  }

  const handleApprove = async () => {
    setIsUpdating(true)
    try {
      const response = await apiClient.videos.update(resolvedParams.id, {
        qualityStatus: "PASSED",
      })
      if (response.error) {
        throw new Error(response.error.message ?? "Failed to update")
      }
      setVideo((prev) => (prev ? { ...prev, qualityStatus: "PASSED", qualityNote: null } : null))
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to approve")
    } finally {
      setIsUpdating(false)
    }
  }

  const handleFlag = async () => {
    setIsUpdating(true)
    try {
      const response = await apiClient.videos.update(resolvedParams.id, {
        qualityStatus: "FLAGGED",
        qualityNote: flagNote,
      })
      if (response.error) {
        throw new Error(response.error.message ?? "Failed to update")
      }
      setVideo((prev) =>
        prev ? { ...prev, qualityStatus: "FLAGGED", qualityNote: flagNote } : null
      )
      setShowFlag(false)
      setFlagNote("")
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to flag")
    } finally {
      setIsUpdating(false)
    }
  }

  const handleDelete = async () => {
    if (!confirm("Delete this video? This cannot be undone.")) return

    try {
      const response = await apiClient.videos.delete(resolvedParams.id)
      if (response.error) {
        throw new Error(response.error.message ?? "Failed to delete")
      }
      router.push("/videos")
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to delete")
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
          <button onClick={loadVideo} className="underline">
            Retry
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="container mx-auto px-4 py-4">
          <Link href="/videos" className="text-sm text-muted-foreground hover:underline">
            ← Back to Video Library
          </Link>
        </div>
      </header>

      <main className="container mx-auto px-4 py-6">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Video Player */}
          <div className="lg:col-span-2">
            <div className="bg-card rounded-lg border overflow-hidden">
              <div className="aspect-[9/16] max-h-[600px] bg-black">
                {video.videoUrl ? (
                  <video
                    src={video.videoUrl}
                    className="w-full h-full object-contain"
                    controls
                    autoPlay={false}
                  />
                ) : (
                  <div className="flex items-center justify-center h-full text-muted-foreground">
                    Video not available
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Status & Actions */}
            <section className="bg-card rounded-lg border p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold">Quality Review</h2>
                <span
                  className={`px-3 py-1 text-sm rounded ${
                    video.qualityStatus === "PASSED"
                      ? "bg-green-100 text-green-800"
                      : video.qualityStatus === "FLAGGED"
                        ? "bg-red-100 text-red-800"
                        : "bg-yellow-100 text-yellow-800"
                  }`}
                >
                  {video.qualityStatus}
                </span>
              </div>

              {video.qualityNote && (
                <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded">
                  <p className="text-sm text-red-800">
                    <strong>Flag Note:</strong> {video.qualityNote}
                  </p>
                </div>
              )}

              <div className="space-y-2">
                {video.qualityStatus !== "PASSED" && (
                  <button
                    onClick={handleApprove}
                    disabled={isUpdating}
                    className="w-full px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-50"
                  >
                    {isUpdating ? "Updating..." : "Approve Video"}
                  </button>
                )}
                {video.qualityStatus !== "FLAGGED" && (
                  <button
                    onClick={() => setShowFlag(true)}
                    disabled={isUpdating}
                    className="w-full px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-50"
                  >
                    Flag Quality Issue
                  </button>
                )}
                {video.qualityStatus === "PASSED" && (
                  <Link
                    href={`/videos/${video.id}/iterate`}
                    className="block w-full px-4 py-2 bg-primary text-primary-foreground rounded hover:bg-primary/90 text-center"
                  >
                    Iterate on Winner
                  </Link>
                )}
              </div>
            </section>

            {/* Metadata */}
            <section className="bg-card rounded-lg border p-6">
              <h2 className="text-lg font-semibold mb-4">Details</h2>
              <dl className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Status</dt>
                  <dd>{video.status}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Cost</dt>
                  <dd>${video.totalCost}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Created</dt>
                  <dd>{new Date(video.createdAt).toLocaleString()}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Script Provider</dt>
                  <dd>{video.scriptProvider ?? "N/A"}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Avatar Provider</dt>
                  <dd>{video.avatarProvider ?? "N/A"}</dd>
                </div>
              </dl>

              <div className="mt-4 pt-4 border-t">
                <Link
                  href={`/generations/${video.generationId}`}
                  className="text-sm text-primary hover:underline"
                >
                  View Generation Batch →
                </Link>
              </div>
            </section>

            {/* Cost Breakdown */}
            <section className="bg-card rounded-lg border p-6">
              <button
                onClick={loadCosts}
                className="flex items-center justify-between w-full"
              >
                <h2 className="text-lg font-semibold">Cost Breakdown</h2>
                <span className="text-sm text-muted-foreground">
                  {showCosts ? "▲" : "▼"}
                </span>
              </button>

              {showCosts && costs && (
                <div className="mt-4 space-y-3">
                  {costs.breakdown.map((item, i) => (
                    <div key={i} className="flex justify-between text-sm">
                      <span className="text-muted-foreground">
                        {item.serviceType} ({item.provider})
                      </span>
                      <span>${parseFloat(item.cost).toFixed(6)}</span>
                    </div>
                  ))}
                  <div className="flex justify-between text-sm font-medium pt-2 border-t">
                    <span>Total</span>
                    <span>${costs.totalCost}</span>
                  </div>
                </div>
              )}
            </section>

            {/* Generation Params */}
            {video.generationParams.script && (
              <section className="bg-card rounded-lg border p-6">
                <h2 className="text-lg font-semibold mb-4">Script</h2>
                <div className="space-y-3 text-sm">
                  <div>
                    <p className="text-muted-foreground mb-1">Hook</p>
                    <p>{video.generationParams.script.hook}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground mb-1">Testimonial</p>
                    <p className="whitespace-pre-wrap">
                      {video.generationParams.script.testimonialScript}
                    </p>
                  </div>
                  <div>
                    <p className="text-muted-foreground mb-1">Call to Action</p>
                    <p>{video.generationParams.script.callToAction}</p>
                  </div>
                </div>
              </section>
            )}

            {/* Download & Delete */}
            <section className="bg-card rounded-lg border p-6 space-y-2">
              {video.videoUrl && (
                <>
                  <a
                    href={video.videoUrl}
                    download
                    className="block w-full px-4 py-2 border rounded hover:bg-muted text-center"
                  >
                    Download Video
                  </a>
                  <button
                    onClick={() => {
                      navigator.clipboard.writeText(video.videoUrl!)
                      alert("URL copied to clipboard")
                    }}
                    className="w-full px-4 py-2 border rounded hover:bg-muted"
                  >
                    Copy URL
                  </button>
                </>
              )}
              <button
                onClick={handleDelete}
                className="w-full px-4 py-2 border border-destructive text-destructive rounded hover:bg-destructive/10"
              >
                Delete Video
              </button>
            </section>
          </div>
        </div>
      </main>

      {/* Flag Modal */}
      {showFlag && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-background rounded-lg border shadow-lg w-full max-w-md mx-4">
            <div className="flex items-center justify-between p-4 border-b">
              <h2 className="text-lg font-semibold">Flag Quality Issue</h2>
              <button
                onClick={() => setShowFlag(false)}
                className="text-muted-foreground hover:text-foreground"
              >
                ✕
              </button>
            </div>

            <div className="p-4">
              <label className="block text-sm font-medium mb-2">
                Describe the issue
              </label>
              <textarea
                value={flagNote}
                onChange={(e) => setFlagNote(e.target.value)}
                rows={4}
                className="w-full p-3 rounded-lg border bg-background resize-none"
                placeholder="e.g., Visual artifacts, audio sync issues, incoherent content..."
              />
            </div>

            <div className="flex justify-end gap-2 p-4 border-t">
              <button
                onClick={() => setShowFlag(false)}
                className="px-4 py-2 border rounded hover:bg-muted"
              >
                Cancel
              </button>
              <button
                onClick={handleFlag}
                disabled={isUpdating}
                className="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-50"
              >
                {isUpdating ? "Flagging..." : "Flag Video"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
