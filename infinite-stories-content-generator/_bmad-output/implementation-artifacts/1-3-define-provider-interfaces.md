# Story 1.3: Define Provider Interfaces

## Story

As a developer,
I want provider interfaces defined using Interface + Factory pattern,
So that I can swap AI providers without changing business logic.

## Status

completed

## Acceptance Criteria

- [x] **AC1**: types.ts exists with IScriptProvider, IAvatarProvider, IVideoProvider interfaces
- [x] **AC2**: factory.ts exports createProvider() function
- [x] **AC3**: IScriptProvider defines generate(brief) returning Effect
- [x] **AC4**: IAvatarProvider defines generate(script) returning Effect
- [x] **AC5**: IVideoProvider defines compose(avatar, broll) returning Effect
- [x] **AC6**: All interfaces use Effect return types for error handling
- [x] **AC7**: Barrel exports in index.ts for the module

## Tasks/Subtasks

- [x] **Task 1**: Create provider types
  - [x] Create src/lib/providers/types.ts
  - [x] Define ParsedBrief type
  - [x] Define Script type
  - [x] Define AvatarClip type
  - [x] Define BRollClip type
  - [x] Define ComposedVideo type
- [x] **Task 2**: Define error types for providers
  - [x] ScriptError type (discriminated union with _tag)
  - [x] AvatarError type (discriminated union with _tag)
  - [x] VideoError type (discriminated union with _tag)
- [x] **Task 3**: Define provider interfaces
  - [x] IScriptProvider interface with Effect return
  - [x] IAvatarProvider interface with Effect return
  - [x] IVideoProvider interface with Effect return
- [x] **Task 4**: Create factory function
  - [x] Create src/lib/providers/factory.ts
  - [x] createProvider() for script, avatar, video types
  - [x] Config-based provider selection via env vars
- [x] **Task 5**: Create placeholder implementations
  - [x] src/lib/providers/script/index.ts (mock provider)
  - [x] src/lib/providers/avatar/index.ts (mock provider)
  - [x] src/lib/providers/video/index.ts (mock provider)
- [x] **Task 6**: Create barrel exports
  - [x] src/lib/providers/index.ts

## Dev Notes

### Architecture Requirements
- Interface + Factory pattern for provider abstraction
- Effect library for typed error handling
- All AI calls must go through providers
- Log costs after every call via CostLog model

### Technical Specifications
- Effect library installed
- Discriminated unions with _tag for error types
- Type-safe factory function with conditional return types

## Dev Agent Record

### Implementation Plan
1. Install Effect library
2. Create types.ts with all data types and error types
3. Define provider interfaces with Effect returns
4. Create factory function with env-based provider selection
5. Implement mock providers for development
6. Create barrel exports

### Debug Log
- Effect library installed successfully
- All types using discriminated unions with _tag
- Mock providers return Effect.succeed for testing

### Completion Notes
All acceptance criteria satisfied:
- 5 data types: ParsedBrief, Script, AvatarClip, BRollClip, ComposedVideo
- 3 error types: ScriptError, AvatarError, VideoError (all with _tag)
- 3 interfaces: IScriptProvider, IAvatarProvider, IVideoProvider
- Factory function with type-safe conditional returns
- Mock providers for all three types
- Build passes, lint has 1 minor warning (unused param in mock)

## File List

_Files created/modified by this story:_

**New Files:**
- `src/lib/providers/types.ts` - All types and interfaces
- `src/lib/providers/factory.ts` - Provider factory function
- `src/lib/providers/script/index.ts` - Mock script provider
- `src/lib/providers/avatar/index.ts` - Mock avatar provider
- `src/lib/providers/video/index.ts` - Mock video provider
- `src/lib/providers/index.ts` - Barrel exports

**Modified Files:**
- `package.json` - Added effect dependency

## Change Log

| Date | Change |
|------|--------|
| 2026-01-09 | Story created from Epic 1 |
| 2026-01-09 | Implementation completed - all ACs satisfied |
