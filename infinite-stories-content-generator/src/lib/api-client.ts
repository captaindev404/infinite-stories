/**
 * API Client for making authenticated requests
 */

const API_BASE = ""

type ApiResponse<T> = {
  data: T | null
  error: { _tag: string; message?: string } | null
  meta: { timestamp: string }
}

async function request<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<ApiResponse<T>> {
  const token = typeof window !== "undefined"
    ? localStorage.getItem("admin_token") ?? ""
    : ""

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...options.headers,
    },
  })

  return response.json()
}

export const apiClient = {
  // Brief endpoints
  briefs: {
    list: (limit = 20, offset = 0) =>
      request<{ items: Brief[]; total: number; limit: number; offset: number }>(
        `/api/briefs?limit=${limit}&offset=${offset}`
      ),

    get: (id: string) => request<BriefWithGenerations>(`/api/briefs/${id}`),

    create: (rawInput: string) =>
      request<Brief>("/api/briefs", {
        method: "POST",
        body: JSON.stringify({ rawInput }),
      }),

    update: (id: string, rawInput: string) =>
      request<Brief>(`/api/briefs/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ rawInput }),
      }),

    delete: (id: string) =>
      request<{ deleted: boolean }>(`/api/briefs/${id}`, {
        method: "DELETE",
      }),

    parse: (id: string) =>
      request<Brief>(`/api/briefs/${id}/parse`, {
        method: "POST",
      }),

    duplicate: (id: string) =>
      request<Brief>(`/api/briefs/${id}/duplicate`, {
        method: "POST",
      }),

    // Generation endpoints within briefs
    createGeneration: (briefId: string, targetCount: number) =>
      request<Generation>(`/api/briefs/${briefId}/generations`, {
        method: "POST",
        body: JSON.stringify({ targetCount }),
      }),

    listGenerations: (briefId: string) =>
      request<{ items: GenerationSummary[]; total: number }>(
        `/api/briefs/${briefId}/generations`
      ),
  },

  // Generation endpoints
  generations: {
    get: (id: string) => request<GenerationDetail>(`/api/generations/${id}`),
  },

  // Video endpoints
  videos: {
    list: (params?: VideoListParams) => {
      const query = new URLSearchParams()
      if (params?.limit) query.set("limit", String(params.limit))
      if (params?.offset) query.set("offset", String(params.offset))
      if (params?.qualityStatus) query.set("qualityStatus", params.qualityStatus)
      if (params?.status) query.set("status", params.status)
      if (params?.briefId) query.set("briefId", params.briefId)
      if (params?.generationId) query.set("generationId", params.generationId)
      return request<{ items: Video[]; total: number }>(`/api/videos?${query}`)
    },

    get: (id: string) => request<VideoDetail>(`/api/videos/${id}`),

    update: (id: string, data: VideoUpdateData) =>
      request<Video>(`/api/videos/${id}`, {
        method: "PATCH",
        body: JSON.stringify(data),
      }),

    delete: (id: string) =>
      request<{ deleted: boolean }>(`/api/videos/${id}`, {
        method: "DELETE",
      }),

    getCosts: (id: string) => request<VideoCosts>(`/api/videos/${id}/costs`),
  },

  // Cost statistics endpoints
  costs: {
    stats: (period: "daily" | "weekly" | "monthly" = "daily") =>
      request<CostStats>(`/api/cost-logs/stats?period=${period}`),
  },
}

// Types
export type Brief = {
  id: string
  rawInput: string
  parsedData: ParsedBrief | null
  status: "DRAFT" | "PARSED"
  createdAt: string
  updatedAt: string
}

export type ParsedBrief = {
  hook: string
  persona: {
    type: string
    age: string
    demographic: string
    tone: string
  }
  emotion: string
  brollTags: string[]
  testimonialPoints: string[]
}

export type BriefWithGenerations = Brief & {
  generations: {
    id: string
    status: string
    targetCount: number
    totalCost: string
    createdAt: string
  }[]
}

// Generation types
export type GenerationStatus =
  | "PENDING"
  | "QUEUED"
  | "SCRIPT_GEN"
  | "AVATAR_GEN"
  | "VIDEO_GEN"
  | "COMPOSITING"
  | "UPLOADING"
  | "COMPLETED"
  | "FAILED"

export type Generation = {
  id: string
  briefId: string
  targetCount: number
  status: GenerationStatus
  totalCost: string
  createdAt: string
}

export type GenerationSummary = Generation & {
  videoCount: number
}

export type GenerationDetail = Generation & {
  brief: {
    id: string
    rawInput: string
    status: string
  }
  parentGenerationId: string | null
  parentGeneration: {
    id: string
    createdAt: string
  } | null
  videos: VideoSummary[]
  progress: {
    total: number
    completed: number
    failed: number
    pending: number
  }
  childGenerationsCount: number
}

// Video types
export type VideoStatus = "PENDING" | "PROCESSING" | "COMPLETED" | "FAILED"
export type QualityStatus = "PENDING" | "PASSED" | "FLAGGED"

export type VideoSummary = {
  id: string
  videoUrl: string | null
  status: VideoStatus
  qualityStatus: QualityStatus
  totalCost: string
  createdAt: string
}

export type Video = VideoSummary & {
  generationId: string
  avatarProvider: string | null
  scriptProvider: string | null
  qualityNote: string | null
}

export type VideoDetail = Video & {
  generationParams: {
    script?: {
      hook: string
      testimonialScript: string
      callToAction: string
    }
    error?: string
  }
  generation: {
    id: string
    briefId: string
    status: GenerationStatus
  }
}

export type VideoListParams = {
  limit?: number
  offset?: number
  qualityStatus?: QualityStatus
  status?: VideoStatus
  briefId?: string
  generationId?: string
}

export type VideoUpdateData = {
  qualityStatus?: QualityStatus
  qualityNote?: string
}

export type VideoCosts = {
  videoId: string
  totalCost: string
  breakdown: {
    serviceType: string
    provider: string
    operation: string
    cost: string
  }[]
}

// Cost types
export type CostStats = {
  today: string
  thisWeek: string
  thisMonth: string
  allTime: string
  byServiceType: {
    script: string
    avatar: string
    video: string
    storage: string
  }
  daily: {
    date: string
    totalCost: string
    videoCount: number
  }[]
}
