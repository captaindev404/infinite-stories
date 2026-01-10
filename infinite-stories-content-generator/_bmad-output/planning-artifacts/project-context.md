---
project_name: 'infinite-stories-content-generator'
user_name: 'Bro'
date: '2026-01-09'
sections_completed: ['technology_stack', 'implementation_rules', 'testing', 'naming', 'anti_patterns', 'state_machine', 'file_organization']
status: 'complete'
---

# Project Context for AI Agents

_Critical rules for implementing infinite-stories-content-generator. Read before writing any code._

---

## Technology Stack & Versions

| Technology | Version | Notes |
|------------|---------|-------|
| Next.js | 15 | App Router, Turbopack |
| TypeScript | Strict | No `any`, strict null checks |
| Prisma | Latest | PostgreSQL on Dokploy |
| ShadCN | Latest | Default styling |
| Tailwind CSS | 4.x | With ShadCN |
| Zustand | Latest | Client state only |
| React Hook Form | Latest | All forms |
| Effect | Latest | Error handling |
| AWS S3 SDK | Latest | For Cloudflare R2 |

---

## Critical Implementation Rules

### TypeScript Rules

- **Strict mode enabled** - no `any` types, no implicit returns
- **Use `type` over `interface`** for object shapes (Effect convention)
- **Barrel exports** in `index.ts` for each module
- **Path aliases** - use `@/` for `src/` imports

### Next.js App Router Rules

- **Server Components by default** - add `'use client'` only when needed
- **API routes in `app/api/`** - use `route.ts` files
- **Route groups** - use `(pages)/` for page organization
- **Metadata** - export metadata object, not `<Head>`

### Effect Library Rules

- **All errors are typed** - use discriminated unions with `_tag`
- **No throwing exceptions** - return `Effect.fail()` instead
- **Error types defined in `lib/errors/types.ts`**
- **Map Effect results to API responses** in route handlers

### API Response Format (MANDATORY)

```typescript
// Always use this wrapper
type ApiResponse<T> = {
  data: T | null
  error: AppError | null
  meta: { timestamp: string }
}

// Success
{ data: {...}, error: null, meta: { timestamp: "..." } }

// Error
{ data: null, error: { _tag: "ErrorType", ... }, meta: { timestamp: "..." } }
```

### State Management Rules

- **Zustand for client state only** - server is source of truth
- **Status enum pattern** - `'idle' | 'loading' | 'success' | 'error'`
- **Never store API responses in Zustand** - fetch fresh

### Provider Abstraction (MANDATORY)

- **All AI calls go through providers** - never call APIs directly
- **Use factory pattern** - `createProvider('script', providerName)`
- **Log costs after every call** - use `CostLog` model
- **Interfaces in `lib/providers/types.ts`**

---

## Testing Rules

- **Co-located tests** - `component.test.ts` next to `component.tsx`
- **Vitest** - not Jest
- **Test file naming** - `*.test.ts` or `*.test.tsx`
- **Mock providers** - never call real AI APIs in tests

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Components | PascalCase | `BriefChat.tsx` |
| Files | kebab-case | `brief-chat.tsx` |
| Functions | camelCase | `createBrief()` |
| Constants | SCREAMING_SNAKE | `MAX_RETRIES` |
| Types | PascalCase | `GenerationStatus` |
| API routes | lowercase plural | `/api/briefs` |

---

## Critical Anti-Patterns

### NEVER DO:
- Call AI APIs outside provider interfaces
- Use `any` type
- Throw exceptions (use Effect)
- Return bare objects from API (use wrapper)
- Store passwords/keys in code
- Use `snake_case` in TypeScript
- Put tests in `__tests__/` directory
- Use boolean `isLoading` (use status enum)
- Skip cost logging for AI calls

### ALWAYS DO:
- Log costs for every AI provider call
- Use Effect error types
- Follow API response wrapper format
- Check `GenerationStatus` enum for valid transitions
- Use exponential backoff for retries (1s, 2s, 4s, 8s)

---

## Generation Status State Machine

```
PENDING → QUEUED → SCRIPT_GEN → AVATAR_GEN → VIDEO_GEN → COMPOSITING → UPLOADING → COMPLETED
                                                                                  ↘ FAILED
```

Only valid transitions - don't skip states.

---

## File Organization

```
src/
├── app/api/          # API routes only
├── app/(pages)/      # Page components
├── components/ui/    # ShadCN primitives
├── components/common/# Shared components
├── features/         # Domain features (briefs, generations, videos, costs)
├── lib/providers/    # AI provider interfaces
├── lib/db/           # Prisma client + queries
├── lib/errors/       # Effect error types
├── stores/           # Zustand stores
└── types/            # Shared TypeScript types
```

---

_Generated from architecture.md on 2026-01-09_
