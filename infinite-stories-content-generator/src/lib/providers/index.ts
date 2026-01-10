// Provider factory
export { createProvider } from "./factory"

// Types
export type {
  // Data types
  ParsedBrief,
  Script,
  AvatarClip,
  BRollClip,
  ComposedVideo,
  // Error types
  ScriptError,
  AvatarError,
  VideoError,
  // Interfaces
  IScriptProvider,
  IAvatarProvider,
  IVideoProvider,
  // Config
  ProviderType,
  ProviderConfig,
} from "./types"

// Individual provider factories (for direct use if needed)
export { createMockScriptProvider } from "./script"
export { createMockAvatarProvider } from "./avatar"
export { createMockVideoProvider } from "./video"
