"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { BriefList } from "@/components/briefs/brief-list"
import { ChatInput } from "@/components/briefs/chat-input"

export default function BriefsPage() {
  const router = useRouter()
  const [showChat, setShowChat] = useState(false)

  const handleBriefCreated = (briefId: string) => {
    router.push(`/briefs/${briefId}`)
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <h1 className="text-2xl font-bold">Content Briefs</h1>
          <button
            onClick={() => setShowChat(!showChat)}
            className="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90"
          >
            {showChat ? "View List" : "New Brief"}
          </button>
        </div>
      </header>

      <main className="container mx-auto">
        {showChat ? (
          <div className="h-[calc(100vh-80px)]">
            <ChatInput onBriefCreated={handleBriefCreated} />
          </div>
        ) : (
          <BriefList />
        )}
      </main>
    </div>
  )
}
