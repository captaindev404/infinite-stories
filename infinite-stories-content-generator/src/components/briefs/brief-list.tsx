"use client"

import { useEffect, useState, useCallback } from "react"
import Link from "next/link"
import { apiClient, Brief } from "@/lib/api-client"
import { useBriefStore } from "@/stores/brief-store"

export function BriefList() {
  const [briefs, setBriefs] = useState<Brief[]>([])
  const [total, setTotal] = useState(0)
  const { listStatus, listError, setListStatus } = useBriefStore()

  const loadBriefs = useCallback(async () => {
    setListStatus("loading")
    try {
      const response = await apiClient.briefs.list()
      if (response.error || !response.data) {
        throw new Error(response.error?.message ?? "Failed to load briefs")
      }
      setBriefs(response.data.items)
      setTotal(response.data.total)
      setListStatus("success")
    } catch (error) {
      setListStatus(
        "error",
        error instanceof Error ? error.message : "Failed to load"
      )
    }
  }, [setListStatus])

  useEffect(() => {
    loadBriefs()
  }, [loadBriefs])

  if (listStatus === "loading") {
    return <div className="p-4">Loading briefs...</div>
  }

  if (listStatus === "error") {
    return (
      <div className="p-4 text-destructive">
        Error: {listError}
        <button onClick={loadBriefs} className="ml-2 underline">
          Retry
        </button>
      </div>
    )
  }

  if (briefs.length === 0) {
    return (
      <div className="p-4 text-center text-muted-foreground">
        No briefs yet. Create your first one!
      </div>
    )
  }

  return (
    <div className="divide-y">
      <div className="p-2 text-sm text-muted-foreground">
        {total} brief{total !== 1 ? "s" : ""}
      </div>
      {briefs.map((brief) => (
        <Link
          key={brief.id}
          href={`/briefs/${brief.id}`}
          className="block p-4 hover:bg-muted/50 transition-colors"
        >
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1 min-w-0">
              <p className="text-sm truncate">{brief.rawInput}</p>
              <p className="text-xs text-muted-foreground mt-1">
                {new Date(brief.createdAt).toLocaleDateString()}
              </p>
            </div>
            <span
              className={`px-2 py-1 text-xs rounded ${
                brief.status === "PARSED"
                  ? "bg-green-100 text-green-800"
                  : "bg-yellow-100 text-yellow-800"
              }`}
            >
              {brief.status}
            </span>
          </div>
        </Link>
      ))}
    </div>
  )
}
