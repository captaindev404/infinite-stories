"use client"

import { useState } from "react"
import { useForm } from "react-hook-form"
import { useBriefStore } from "@/stores/brief-store"
import { apiClient } from "@/lib/api-client"

type FormData = {
  rawInput: string
}

type ChatInputProps = {
  onBriefCreated: (briefId: string) => void
}

export function ChatInput({ onBriefCreated }: ChatInputProps) {
  const [messages, setMessages] = useState<
    { role: "user" | "system"; content: string }[]
  >([
    {
      role: "system",
      content:
        "Welcome! Describe your TikTok ad concept. Include details about the target audience, emotional hook, and key messages you want to convey.",
    },
  ])

  const { createStatus, parseStatus, setCreateStatus, setParseStatus } =
    useBriefStore()

  const { register, handleSubmit, reset } = useForm<FormData>()

  const isLoading = createStatus === "loading" || parseStatus === "loading"

  const onSubmit = async (data: FormData) => {
    if (!data.rawInput.trim()) return

    // Add user message
    setMessages((prev) => [...prev, { role: "user", content: data.rawInput }])
    reset()

    try {
      // Create brief
      setCreateStatus("loading")
      const createResponse = await apiClient.briefs.create(data.rawInput)

      if (createResponse.error || !createResponse.data) {
        throw new Error(createResponse.error?.message ?? "Failed to create brief")
      }

      setCreateStatus("success")
      const briefId = createResponse.data.id

      // Parse brief
      setParseStatus("loading")
      setMessages((prev) => [
        ...prev,
        { role: "system", content: "Analyzing your brief..." },
      ])

      const parseResponse = await apiClient.briefs.parse(briefId)

      if (parseResponse.error || !parseResponse.data) {
        throw new Error(parseResponse.error?.message ?? "Failed to parse brief")
      }

      setParseStatus("success")

      // Show parsed result
      const parsed = parseResponse.data.parsedData
      if (parsed) {
        setMessages((prev) => [
          ...prev,
          {
            role: "system",
            content: `Great! I've analyzed your brief:

**Hook:** ${parsed.hook}

**Target Persona:** ${parsed.persona.type} (${parsed.persona.age}, ${parsed.persona.tone} tone)

**Emotion:** ${parsed.emotion}

**B-Roll Scenes:** ${parsed.brollTags.join(", ")}

**Key Messages:**
${parsed.testimonialPoints.map((p) => `• ${p}`).join("\n")}

Ready to generate videos?`,
          },
        ])
      }

      onBriefCreated(briefId)
    } catch (error) {
      const message = error instanceof Error ? error.message : "An error occurred"
      setCreateStatus("error", message)
      setMessages((prev) => [
        ...prev,
        { role: "system", content: `Error: ${message}` },
      ])
    }
  }

  return (
    <div className="flex flex-col h-full">
      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg, i) => (
          <div
            key={i}
            className={`p-3 rounded-lg max-w-[80%] ${
              msg.role === "user"
                ? "bg-primary text-primary-foreground ml-auto"
                : "bg-muted"
            }`}
          >
            <pre className="whitespace-pre-wrap font-sans text-sm">
              {msg.content}
            </pre>
          </div>
        ))}
        {isLoading && (
          <div className="bg-muted p-3 rounded-lg max-w-[80%]">
            <div className="flex items-center gap-2">
              <div className="animate-pulse">●</div>
              <span className="text-sm">Processing...</span>
            </div>
          </div>
        )}
      </div>

      {/* Input */}
      <form onSubmit={handleSubmit(onSubmit)} className="p-4 border-t">
        <div className="flex gap-2">
          <textarea
            {...register("rawInput")}
            placeholder="Describe your ad concept..."
            className="flex-1 min-h-[80px] p-3 rounded-lg border bg-background resize-none"
            disabled={isLoading}
          />
          <button
            type="submit"
            disabled={isLoading}
            className="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            Send
          </button>
        </div>
      </form>
    </div>
  )
}
