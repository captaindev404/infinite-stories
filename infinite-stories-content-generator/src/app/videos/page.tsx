"use client"

import { useEffect, useState, useCallback } from "react"
import Link from "next/link"
import { apiClient, Video, QualityStatus, VideoStatus } from "@/lib/api-client"

export default function VideoLibraryPage() {
  const [videos, setVideos] = useState<Video[]>([])
  const [total, setTotal] = useState(0)
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading")
  const [error, setError] = useState<string | null>(null)

  // Filters
  const [qualityFilter, setQualityFilter] = useState<QualityStatus | "">("")
  const [statusFilter, setStatusFilter] = useState<VideoStatus | "">("")
  const [page, setPage] = useState(0)
  const [selectedVideos, setSelectedVideos] = useState<Set<string>>(new Set())

  const limit = 20

  const loadVideos = useCallback(async () => {
    setStatus("loading")
    try {
      const response = await apiClient.videos.list({
        limit,
        offset: page * limit,
        qualityStatus: qualityFilter || undefined,
        status: statusFilter || undefined,
      })
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to load videos")
      }
      setVideos(response.data.items)
      setTotal(response.data.total)
      setStatus("success")
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load")
      setStatus("error")
    }
  }, [page, qualityFilter, statusFilter])

  useEffect(() => {
    loadVideos()
  }, [loadVideos])

  const handleQualityUpdate = async (videoId: string, newStatus: QualityStatus) => {
    try {
      const response = await apiClient.videos.update(videoId, { qualityStatus: newStatus })
      if (response.error) {
        throw new Error(response.error.message ?? "Failed to update")
      }
      setVideos((prev) =>
        prev.map((v) => (v.id === videoId ? { ...v, qualityStatus: newStatus } : v))
      )
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to update")
    }
  }

  const handleBatchApprove = async () => {
    if (selectedVideos.size === 0) return

    try {
      await Promise.all(
        Array.from(selectedVideos).map((id) =>
          apiClient.videos.update(id, { qualityStatus: "PASSED" })
        )
      )
      setVideos((prev) =>
        prev.map((v) =>
          selectedVideos.has(v.id) ? { ...v, qualityStatus: "PASSED" } : v
        )
      )
      setSelectedVideos(new Set())
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to approve")
    }
  }

  const handleDelete = async (videoId: string) => {
    if (!confirm("Delete this video? This cannot be undone.")) return

    try {
      const response = await apiClient.videos.delete(videoId)
      if (response.error) {
        throw new Error(response.error.message ?? "Failed to delete")
      }
      setVideos((prev) => prev.filter((v) => v.id !== videoId))
      setTotal((prev) => prev - 1)
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to delete")
    }
  }

  const toggleSelect = (videoId: string) => {
    setSelectedVideos((prev) => {
      const next = new Set(prev)
      if (next.has(videoId)) {
        next.delete(videoId)
      } else {
        next.add(videoId)
      }
      return next
    })
  }

  const toggleSelectAll = () => {
    if (selectedVideos.size === videos.length) {
      setSelectedVideos(new Set())
    } else {
      setSelectedVideos(new Set(videos.map((v) => v.id)))
    }
  }

  const totalPages = Math.ceil(total / limit)

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-bold">Video Library</h1>
            <div className="flex gap-4">
              <Link href="/costs" className="text-sm text-muted-foreground hover:underline">
                View Costs
              </Link>
              <Link href="/briefs" className="text-sm text-muted-foreground hover:underline">
                ← Back to Briefs
              </Link>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-6">
        {/* Filters */}
        <div className="flex flex-wrap gap-4 mb-6">
          <select
            value={qualityFilter}
            onChange={(e) => {
              setQualityFilter(e.target.value as QualityStatus | "")
              setPage(0)
            }}
            className="px-3 py-2 border rounded bg-background"
          >
            <option value="">All Quality Status</option>
            <option value="PENDING">Pending Review</option>
            <option value="PASSED">Approved</option>
            <option value="FLAGGED">Flagged</option>
          </select>

          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value as VideoStatus | "")
              setPage(0)
            }}
            className="px-3 py-2 border rounded bg-background"
          >
            <option value="">All Status</option>
            <option value="COMPLETED">Completed</option>
            <option value="PROCESSING">Processing</option>
            <option value="FAILED">Failed</option>
          </select>

          {selectedVideos.size > 0 && (
            <button
              onClick={handleBatchApprove}
              className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
            >
              Approve Selected ({selectedVideos.size})
            </button>
          )}

          <div className="ml-auto text-sm text-muted-foreground">
            {total} video{total !== 1 ? "s" : ""}
          </div>
        </div>

        {status === "loading" && (
          <div className="flex items-center justify-center py-12">
            <p>Loading videos...</p>
          </div>
        )}

        {status === "error" && (
          <div className="flex items-center justify-center py-12">
            <div className="text-center">
              <p className="text-destructive mb-4">Error: {error}</p>
              <button onClick={loadVideos} className="underline">
                Retry
              </button>
            </div>
          </div>
        )}

        {status === "success" && videos.length === 0 && (
          <div className="flex items-center justify-center py-12">
            <p className="text-muted-foreground">No videos found</p>
          </div>
        )}

        {status === "success" && videos.length > 0 && (
          <>
            {/* Select All */}
            <div className="mb-4">
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={selectedVideos.size === videos.length}
                  onChange={toggleSelectAll}
                  className="rounded"
                />
                Select all on this page
              </label>
            </div>

            {/* Video Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 mb-6">
              {videos.map((video) => (
                <div
                  key={video.id}
                  className={`bg-card rounded-lg border overflow-hidden ${
                    selectedVideos.has(video.id) ? "ring-2 ring-primary" : ""
                  }`}
                >
                  {/* Thumbnail / Video Preview */}
                  <div className="aspect-[9/16] bg-muted relative">
                    {video.videoUrl ? (
                      <video
                        src={video.videoUrl}
                        className="w-full h-full object-cover"
                        controls
                      />
                    ) : (
                      <div className="flex items-center justify-center h-full text-muted-foreground">
                        No video
                      </div>
                    )}

                    {/* Selection checkbox */}
                    <div className="absolute top-2 left-2">
                      <input
                        type="checkbox"
                        checked={selectedVideos.has(video.id)}
                        onChange={() => toggleSelect(video.id)}
                        className="rounded"
                      />
                    </div>

                    {/* Quality badge */}
                    <div className="absolute top-2 right-2">
                      <span
                        className={`px-2 py-1 text-xs rounded ${
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
                  </div>

                  {/* Info */}
                  <div className="p-3">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-xs text-muted-foreground">
                        {new Date(video.createdAt).toLocaleDateString()}
                      </span>
                      <span className="text-xs font-medium">${video.totalCost}</span>
                    </div>

                    {/* Actions */}
                    <div className="flex gap-2">
                      {video.qualityStatus !== "PASSED" && (
                        <button
                          onClick={() => handleQualityUpdate(video.id, "PASSED")}
                          className="flex-1 px-2 py-1 text-xs bg-green-100 text-green-800 rounded hover:bg-green-200"
                        >
                          Approve
                        </button>
                      )}
                      {video.qualityStatus !== "FLAGGED" && (
                        <button
                          onClick={() => handleQualityUpdate(video.id, "FLAGGED")}
                          className="flex-1 px-2 py-1 text-xs bg-red-100 text-red-800 rounded hover:bg-red-200"
                        >
                          Flag
                        </button>
                      )}
                      <button
                        onClick={() => handleDelete(video.id)}
                        className="px-2 py-1 text-xs border rounded hover:bg-muted"
                      >
                        Delete
                      </button>
                    </div>

                    {/* Download */}
                    {video.videoUrl && (
                      <a
                        href={video.videoUrl}
                        download
                        className="block mt-2 text-center text-xs text-primary hover:underline"
                      >
                        Download
                      </a>
                    )}
                  </div>
                </div>
              ))}
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-center gap-2">
                <button
                  onClick={() => setPage((p) => Math.max(0, p - 1))}
                  disabled={page === 0}
                  className="px-3 py-1 border rounded disabled:opacity-50"
                >
                  Previous
                </button>
                <span className="text-sm text-muted-foreground">
                  Page {page + 1} of {totalPages}
                </span>
                <button
                  onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
                  disabled={page >= totalPages - 1}
                  className="px-3 py-1 border rounded disabled:opacity-50"
                >
                  Next
                </button>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  )
}
