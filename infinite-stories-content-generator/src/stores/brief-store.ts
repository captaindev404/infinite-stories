import { create } from "zustand"

type Status = "idle" | "loading" | "success" | "error"

type BriefStore = {
  // List state
  listStatus: Status
  listError: string | null

  // Create state
  createStatus: Status
  createError: string | null

  // Parse state
  parseStatus: Status
  parseError: string | null

  // Actions
  setListStatus: (status: Status, error?: string) => void
  setCreateStatus: (status: Status, error?: string) => void
  setParseStatus: (status: Status, error?: string) => void
  reset: () => void
}

export const useBriefStore = create<BriefStore>((set) => ({
  listStatus: "idle",
  listError: null,
  createStatus: "idle",
  createError: null,
  parseStatus: "idle",
  parseError: null,

  setListStatus: (status, error) =>
    set({ listStatus: status, listError: error ?? null }),

  setCreateStatus: (status, error) =>
    set({ createStatus: status, createError: error ?? null }),

  setParseStatus: (status, error) =>
    set({ parseStatus: status, parseError: error ?? null }),

  reset: () =>
    set({
      listStatus: "idle",
      listError: null,
      createStatus: "idle",
      createError: null,
      parseStatus: "idle",
      parseError: null,
    }),
}))
