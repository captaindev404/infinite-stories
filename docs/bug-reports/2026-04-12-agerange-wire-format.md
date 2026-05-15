# Bug Report — AgeRange Wire-Format Identity Split

**Date:** 2026-04-12
**Severity:** CRITICAL (architectural — latent data corruption risk)
**Found by:** `linus` code review agent during l10n sweep bundle review (task #81)
**Tracked as:** Task #89 (L10N-81-FOLLOWUP)
**Status:** Option A (safeguards) shipped. Option B (structural fix) pending.

---

## Summary

`AgeRange` is a Swift enum whose `rawValue` serves **three conflicting purposes simultaneously**:

1. **Wire-format identifier** — serialized to the backend `ageRange` field via `ageRange.rawValue` in `CustomEventAIAssistant.swift:105`
2. **Codable decode key** — deserialized from backend JSON via `AgeRange(rawValue: ageRange)` in `CustomStoryEvent.swift:190`
3. **Former display string** — was rendered verbatim in French UI badges (fixed by l10n sweep, now routed through `localizedName`)

The display-leak is fixed. The structural trap remains: **if any developer ever edits a `rawValue` string, every existing user's custom-event records silently lose their age-range classification on the next sync.** There is no compile-time guard, no migration, and no test until the Option A regression suite was added on 2026-04-11.

---

## Current state (after Option A)

```swift
// Models/CustomStoryEvent.swift

/// ⚠️ Wire-format contract — DO NOT EDIT rawValue strings.
/// "2-4 years", "4-6 years", "6-10 years", "All Ages" are persisted
/// to the backend and decoded from backend responses.
enum AgeRange: String, Codable, CaseIterable {
    case toddler = "2-4 years"
    case preschool = "4-6 years"
    case elementary = "6-10 years"
    case all = "All Ages"

    var localizedName: String { /* routes through xcstrings */ }
    var apiIdentifier: String { rawValue }
}
```

**Safeguards in place (Option A):**
- Doc comment with explicit "DO NOT EDIT" contract
- `AgeRangeWireFormatTests` suite: pins all 4 rawValues, round-trip via `rawValue`, JSON encode/decode
- All UI display sites use `localizedName` (xcstrings), never `rawValue`
- `apiIdentifier` property documented as the non-UI alias

**What Option A does NOT fix:**
- rawValue is still a human-readable English string, not a stable machine identifier
- A developer who "cleans up" the enum to use cleaner codes (e.g. `case all = "all"`) passes `swiftlint`, passes type-checking, and only breaks at runtime when legacy records decode as `nil`
- No backward-compat Codable exists to accept both legacy and new formats

---

## Root cause analysis

### iOS enum design

The enum was created with English display strings as rawValues — a common Swift anti-pattern when the same type is used for both UI display and serialization:

```swift
case all = "All Ages"    // Display string, not a stable identifier
```

Compare with `StoryTone`, which was designed correctly from the start:

```swift
case calming = "calming"  // Stable code, display routed through localizedName
```

### Backend contract

The backend treats `ageRange` as a **free-form string** with no enum validation:

| Layer | Definition | Constraint |
|---|---|---|
| Prisma schema | `ageRange String?` | None — any string accepted |
| Zod (create) | `z.string().min(1).max(50)` | Length only |
| Zod (update) | `z.string().max(20).optional()` | Length only |
| Zod (enhance) | `z.string().max(50).optional()` | Length only |

The Prisma schema comment (`e.g., "3-5", "6-8", "9-12"`) suggests the original design anticipated different range formats than what iOS currently sends.

**Key finding: the backend will accept new stable codes (`"all"`, `"toddler"`, etc.) without any backend-side change.** The Zod validators are string-length-only. No backend migration is required for Option B.

---

## Proposed fix — Option B

Change `rawValue` to stable lowercase codes and add a backward-compatible Codable decoder that accepts both legacy and new formats:

```swift
enum AgeRange: String, Codable, CaseIterable {
    case toddler = "toddler"
    case preschool = "preschool"
    case elementary = "elementary"
    case all = "all"

    // Legacy display strings accepted on decode for backward compat
    private static let legacyMap: [String: AgeRange] = [
        "2-4 years": .toddler,
        "4-6 years": .preschool,
        "6-10 years": .elementary,
        "All Ages": .all,
    ]

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let v = AgeRange(rawValue: raw) { self = v; return }
        if let v = Self.legacyMap[raw] { self = v; return }
        throw DecodingError.dataCorruptedError(
            in: try decoder.singleValueContainer(),
            debugDescription: "Unknown AgeRange: \(raw)"
        )
    }

    // encode uses the new rawValue ("toddler" etc.) automatically
}
```

### Also fix: `eventAgeRange` computed property

`CustomStoryEvent.eventAgeRange` (line ~188) currently calls `AgeRange(rawValue: ageRange)` on a raw `String?` from the backend payload — this bypasses Codable entirely. After Option B the rawValue changes, so this lookup must also apply the legacy fallback:

```swift
var eventAgeRange: AgeRange? {
    guard let ageRange else { return nil }
    return AgeRange(rawValue: ageRange) ?? AgeRange.legacyMap[ageRange]
}
```

Alternatively, expose the legacy map via a factory method:

```swift
static func from(wireValue: String) -> AgeRange? {
    AgeRange(rawValue: wireValue) ?? legacyMap[wireValue]
}
```

---

## Affected files (iOS)

| File | What changes |
|---|---|
| `Models/CustomStoryEvent.swift` | `AgeRange` rawValues, custom `init(from:)`, `eventAgeRange` computed property, expose `legacyMap` or factory |
| `Services/CustomEventAIAssistant.swift:105` | No code change needed — `ageRange.rawValue` will now emit `"toddler"` instead of `"2-4 years"` |
| `InfiniteStoriesTests/DisplayPathFormattingTests.swift` | Update `AgeRangeWireFormatTests` to assert new rawValues + legacy decode |

## Affected files (Backend)

**None.** The Zod schemas accept any string. No migration needed.

However, consider adding a backend-side enum constraint for data quality:

```typescript
// lib/api/schemas.ts — optional hardening
const AgeRangeEnum = z.enum([
  "toddler", "preschool", "elementary", "all",
  // Legacy values accepted for backward compat
  "2-4 years", "4-6 years", "6-10 years", "All Ages",
]);
```

---

## Test plan

| Test | Expected result |
|---|---|
| `AgeRange.all.rawValue` | `"all"` (not `"All Ages"`) |
| `AgeRange(rawValue: "all")` | `.all` |
| `AgeRange(rawValue: "All Ages")` | `nil` (rawValue lookup fails) |
| `AgeRange(from: "All Ages")` via Codable | `.all` (legacy fallback) |
| `AgeRange(from: "all")` via Codable | `.all` (new format) |
| `AgeRange(from: "garbage")` via Codable | throws `DecodingError` |
| `JSONEncoder().encode(AgeRange.all)` | `"all"` |
| `eventAgeRange` with `ageRange = "All Ages"` | `.all` (legacy path) |
| `eventAgeRange` with `ageRange = "all"` | `.all` (new path) |
| Create custom event → backend accepts | 200 OK (staging integration test) |
| Fetch existing custom event with legacy `"All Ages"` | Decodes to `.all` |

---

## Risk assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Backend rejects new codes | **Very low** — Zod is string-length-only | Custom events fail to save | Test against staging before release |
| Legacy records decode as nil | **None** — backward-compat decoder handles it | N/A | Unit tests pin every legacy value |
| Third-party integration sends old format | **Low** — no known third-party consumers | Silent ignore | Legacy map covers all known values |
| Future dev removes legacy map "cleanup" | **Medium** — tempting dead-code-looking code | Existing records break | Comment + test + this bug report |

---

## Deployment sequence

1. **iOS PR:** Change rawValues + add backward-compat Codable + update tests
2. **Staging test:** Create a custom event with the new app → verify backend stores `"toddler"` → fetch it back → verify it decodes
3. **Legacy test:** Fetch an existing custom event with `"All Ages"` stored → verify it decodes to `.all`
4. **Ship iOS update** — no backend deploy needed
5. **(Optional follow-up):** Backend Zod enum hardening to reject unknown strings

---

## Related

- **Origin:** `docs/bug-reports/2026-04-11-l10n-v1.md` finding L10N-08 (FR locale showed "All Ages" instead of "Tous ages")
- **Option A (shipped):** Task #81 — regression test + doc hardening, rawValues unchanged
- **Option B (this report):** Task #89 — structural fix with backward-compat Codable
- **Same pattern elsewhere:** `EventCategory` enum may have the same triple-duty shape — audit separately if confirmed
- **Clean example:** `StoryTone` enum already uses stable lowercase codes — reference implementation
