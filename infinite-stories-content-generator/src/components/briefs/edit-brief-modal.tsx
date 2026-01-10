"use client"

import { useState } from "react"
import { useForm } from "react-hook-form"

type EditBriefModalProps = {
  rawInput: string
  onSave: (rawInput: string) => Promise<void>
  onClose: () => void
}

type FormData = {
  rawInput: string
}

export function EditBriefModal({ rawInput, onSave, onClose }: EditBriefModalProps) {
  const [isSaving, setIsSaving] = useState(false)

  const { register, handleSubmit } = useForm<FormData>({
    defaultValues: { rawInput },
  })

  const onSubmit = async (data: FormData) => {
    if (!data.rawInput.trim()) return

    setIsSaving(true)
    try {
      await onSave(data.rawInput)
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-background rounded-lg border shadow-lg w-full max-w-2xl mx-4">
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold">Edit Brief</h2>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground"
          >
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit(onSubmit)}>
          <div className="p-4">
            <label className="block text-sm font-medium mb-2">Brief Content</label>
            <textarea
              {...register("rawInput")}
              rows={10}
              className="w-full p-3 rounded-lg border bg-background resize-none"
              placeholder="Describe your ad concept..."
              disabled={isSaving}
            />
            <p className="text-xs text-muted-foreground mt-2">
              Editing the brief will reset its parsed status. You&apos;ll need to
              re-parse after saving.
            </p>
          </div>

          <div className="flex justify-end gap-2 p-4 border-t">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 border rounded hover:bg-muted"
              disabled={isSaving}
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSaving}
              className="px-4 py-2 bg-primary text-primary-foreground rounded hover:bg-primary/90 disabled:opacity-50"
            >
              {isSaving ? "Saving..." : "Save Changes"}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
