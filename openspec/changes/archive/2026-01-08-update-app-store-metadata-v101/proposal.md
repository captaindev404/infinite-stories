# Proposal: Update App Store Metadata for v1.0.1

## Summary
Update App Store metadata to reflect the current v1.0.1 release state, correcting language support claims (2 languages instead of 5) and updating version-specific content.

## Motivation
- **Accuracy**: Current metadata incorrectly claims 5-language support; v1.0.1 ships with English and French only
- **App Review compliance**: Metadata must accurately reflect app capabilities to avoid rejection
- **User expectations**: Misleading language claims cause negative reviews and support requests
- **Version alignment**: What's New and promotional text need v1.0.1 updates

## Current State Analysis

### What's Incorrect in `docs/research/APP_STORE_METADATA.md`

| Section | Current State | Correct State |
|---------|---------------|---------------|
| Description | "5 languages" (10+ mentions) | "2 languages" (English & French) |
| Multi-language section | Lists EN, ES, FR, DE, IT | Only EN, FR available |
| What's New | Version 1.0 | Version 1.0.1 |
| Promotional Text | "5 languages!" | "English & French!" |
| Keywords | "multi-language" focus | Reduce language emphasis |
| Reviewer Notes | References 5-language filtering | Correct to 2-language support |
| Pricing justification | Based on 5-language cost | Adjust for 2-language operation |

### Code Reality (from `AppSettings.swift`)
```swift
static let releasedLanguageCodes: Set<String> = ["en", "fr"]
static let releasedLanguageNames: Set<String> = ["English", "French"]
```

## Scope

### In Scope
1. Update all language references from "5 languages" to "English and French"
2. Update What's New for v1.0.1
3. Update promotional text
4. Revise description to emphasize quality over quantity
5. Update reviewer notes with accurate language support
6. Adjust keyword strategy (remove "multi-language" as differentiator)
7. Remove/defer Spanish, German, Italian App Store localization metadata

### Out of Scope
- Creating actual App Store Connect listing (separate task)
- Screenshot creation (separate task)
- Changing app functionality
- Privacy policy content

## Implementation Approach

### Key Messaging Changes

**Before (inaccurate)**:
> "Multi-language support in 5 languages"
> "Content filtering in 5 languages"
> "Native voices in 5 languages"

**After (accurate)**:
> "Available in English and French"
> "Comprehensive content filtering"
> "Native-speaking AI narrators"

### Positioning Strategy
- **Lead with quality** over quantity
- **Emphasize visual storytelling** as primary differentiator (unique to us)
- **Safety first** messaging remains strong
- **Future expansion** mentioned subtly without overpromising

## Success Criteria
- All references to "5 languages" removed or corrected
- Version number updated to 1.0.1
- Description character count remains under 4000
- Keywords optimized for 2-language reality
- Spanish/German/Italian metadata sections marked as "Future Release"
- Document passes internal review for accuracy

## Risks
- **Low**: Less impressive language count may reduce appeal
  - *Mitigation*: Reframe around quality and safety, not quantity
- **Low**: SEO impact from reduced language keywords
  - *Mitigation*: Focus keywords on visual storytelling differentiator

## Related Changes
- `limit-initial-release-languages` - Source of language limitation (complete)
- `prepare-app-store-submission` - Parent submission effort (in progress)
