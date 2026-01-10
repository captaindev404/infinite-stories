"use client"

import { useEffect, useState, useCallback, use } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { apiClient, BriefWithGenerations } from "@/lib/api-client"
import { ParsedBriefView } from "@/components/briefs/parsed-brief-view"
import { EditBriefModal } from "@/components/briefs/edit-brief-modal"
import { BriefHistory } from "@/components/briefs/brief-history"

type PageProps = {
  params: Promise<{ id: string }>
}

export default function BriefDetailPage({ params }: PageProps) {
  const resolvedParams = use(params)
  const router = useRouter()
  const [brief, setBrief] = useState<BriefWithGenerations | null>(null)
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading")
  const [error, setError] = useState<string | null>(null)
  const [showEdit, setShowEdit] = useState(false)
  const [showGenerate, setShowGenerate] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)
  const [isDuplicating, setIsDuplicating] = useState(false)
  const [isParsing, setIsParsing] = useState(false)
  const [isGenerating, setIsGenerating] = useState(false)
  const [targetCount, setTargetCount] = useState(5)

  const loadBrief = useCallback(async () => {
    setStatus("loading")
    try {
      const response = await apiClient.briefs.get(resolvedParams.id)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to load brief")
      }
      setBrief(response.data)
      setStatus("success")
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load")
      setStatus("error")
    }
  }, [resolvedParams.id])

  useEffect(() => {
    loadBrief()
  }, [loadBrief])

  const handleDelete = async () => {
    if (!confirm("Are you sure you want to delete this brief?")) return

    setIsDeleting(true)
    try {
      const response = await apiClient.briefs.delete(resolvedParams.id)
      if (response.error) {
        throw new Error(response.error.message ?? "Failed to delete")
      }
      router.push("/briefs")
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to delete")
    } finally {
      setIsDeleting(false)
    }
  }

  const handleDuplicate = async () => {
    setIsDuplicating(true)
    try {
      const response = await apiClient.briefs.duplicate(resolvedParams.id)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to duplicate")
      }
      router.push(`/briefs/${response.data.id}`)
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to duplicate")
    } finally {
      setIsDuplicating(false)
    }
  }

  const handleParse = async () => {
    setIsParsing(true)
    try {
      const response = await apiClient.briefs.parse(resolvedParams.id)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to parse")
      }
      setBrief((prev) =>
        prev ? { ...prev, parsedData: response.data!.parsedData, status: "PARSED" } : null
      )
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to parse")
    } finally {
      setIsParsing(false)
    }
  }

  const handleGenerate = async () => {
    setIsGenerating(true)
    try {
      const response = await apiClient.briefs.createGeneration(resolvedParams.id, targetCount)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to start generation")
      }
      router.push(`/generations/${response.data.id}`)
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to start generation")
    } finally {
      setIsGenerating(false)
      setShowGenerate(false)
    }
  }

  const handleEditSave = async (rawInput: string) => {
    try {
      const response = await apiClient.briefs.update(resolvedParams.id, rawInput)
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to update")
      }
      setBrief((prev) =>
        prev
          ? { ...prev, rawInput: response.data!.rawInput, status: response.data!.status }
          : null
      )
      setShowEdit(false)
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to update")
    }
  }

  if (status === "loading") {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p>Loading brief...</p>
      </div>
    )
  }

  if (status === "error" || !brief) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <p className="text-destructive mb-4">Error: {error}</p>
          <button onClick={loadBrief} className="underline">
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
          <Link href="/briefs" className="text-sm text-muted-foreground hover:underline">
            ← Back to Briefs
          </Link>
        </div>
      </header>

      <main className="container mx-auto px-4 py-6">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* Raw Input */}
            <section className="bg-card rounded-lg border p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold">Brief Input</h2>
                <div className="flex gap-2">
                  <button
                    onClick={() => setShowEdit(true)}
                    className="px-3 py-1 text-sm border rounded hover:bg-muted"
                  >
                    Edit
                  </button>
                  {brief.status === "DRAFT" && (
                    <button
                      onClick={handleParse}
                      disabled={isParsing}
                      className="px-3 py-1 text-sm bg-primary text-primary-foreground rounded hover:bg-primary/90 disabled:opacity-50"
                    >
                      {isParsing ? "Parsing..." : "Parse Brief"}
                    </button>
                  )}
                </div>
              </div>
              <p className="text-muted-foreground whitespace-pre-wrap">{brief.rawInput}</p>
            </section>

            {/* Parsed Data */}
            {brief.parsedData && (
              <section className="bg-card rounded-lg border p-6">
                <div className="flex items-center justify-between mb-4">
                  <h2 className="text-lg font-semibold">Parsed Brief</h2>
                  <button
                    onClick={() => setShowGenerate(true)}
                    className="px-4 py-2 bg-primary text-primary-foreground rounded hover:bg-primary/90"
                  >
                    Generate Videos
                  </button>
                </div>
                <ParsedBriefView parsedData={brief.parsedData} />
              </section>
            )}

            {/* Generations */}
            {brief.generations && brief.generations.length > 0 && (
              <section className="bg-card rounded-lg border p-6">
                <h2 className="text-lg font-semibold mb-4">Video Generations</h2>
                <div className="space-y-3">
                  {brief.generations.map((gen) => (
                    <div
                      key={gen.id}
                      className="flex items-center justify-between p-3 bg-muted rounded"
                    >
                      <div>
                        <p className="font-medium">{gen.targetCount} videos</p>
                        <p className="text-sm text-muted-foreground">
                          {new Date(gen.createdAt).toLocaleString()}
                        </p>
                      </div>
                      <div className="text-right">
                        <span
                          className={`px-2 py-1 text-xs rounded ${
                            gen.status === "COMPLETED"
                              ? "bg-green-100 text-green-800"
                              : gen.status === "FAILED"
                                ? "bg-red-100 text-red-800"
                                : "bg-yellow-100 text-yellow-800"
                          }`}
                        >
                          {gen.status}
                        </span>
                        <p className="text-sm text-muted-foreground mt-1">${gen.totalCost}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </section>
            )}
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Actions */}
            <section className="bg-card rounded-lg border p-6">
              <h2 className="text-lg font-semibold mb-4">Actions</h2>
              <div className="space-y-3">
                <button
                  onClick={handleDuplicate}
                  disabled={isDuplicating}
                  className="w-full px-4 py-2 border rounded hover:bg-muted disabled:opacity-50"
                >
                  {isDuplicating ? "Duplicating..." : "Duplicate Brief"}
                </button>
                <button
                  onClick={handleDelete}
                  disabled={isDeleting}
                  className="w-full px-4 py-2 border border-destructive text-destructive rounded hover:bg-destructive/10 disabled:opacity-50"
                >
                  {isDeleting ? "Deleting..." : "Delete Brief"}
                </button>
              </div>
            </section>

            {/* History */}
            <section className="bg-card rounded-lg border p-6">
              <h2 className="text-lg font-semibold mb-4">History</h2>
              <BriefHistory brief={brief} />
            </section>
          </div>
        </div>
      </main>

      {/* Edit Modal */}
      {showEdit && (
        <EditBriefModal
          rawInput={brief.rawInput}
          onSave={handleEditSave}
          onClose={() => setShowEdit(false)}
        />
      )}

      {/* Generate Modal */}
      {showGenerate && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-background rounded-lg border shadow-lg w-full max-w-md mx-4">
            <div className="flex items-center justify-between p-4 border-b">
              <h2 className="text-lg font-semibold">Generate Videos</h2>
              <button
                onClick={() => setShowGenerate(false)}
                className="text-muted-foreground hover:text-foreground"
              >
                ✕
              </button>
            </div>

            <div className="p-4 space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">
                  Number of Videos (1-10)
                </label>
                <input
                  type="number"
                  min={1}
                  max={10}
                  value={targetCount}
                  onChange={(e) =>
                    setTargetCount(Math.min(10, Math.max(1, parseInt(e.target.value) || 1)))
                  }
                  className="w-full p-3 rounded-lg border bg-background"
                />
                <p className="text-xs text-muted-foreground mt-2">
                  Each video will have unique script variations based on your brief.
                </p>
              </div>

              <div className="p-3 bg-muted rounded">
                <p className="text-sm">
                  <strong>Estimated cost:</strong> ~${(targetCount * 0.15).toFixed(2)}
                </p>
                <p className="text-xs text-muted-foreground">
                  Based on average cost per video
                </p>
              </div>
            </div>

            <div className="flex justify-end gap-2 p-4 border-t">
              <button
                onClick={() => setShowGenerate(false)}
                className="px-4 py-2 border rounded hover:bg-muted"
                disabled={isGenerating}
              >
                Cancel
              </button>
              <button
                onClick={handleGenerate}
                disabled={isGenerating}
                className="px-4 py-2 bg-primary text-primary-foreground rounded hover:bg-primary/90 disabled:opacity-50"
              >
                {isGenerating ? "Starting..." : `Generate ${targetCount} Videos`}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
