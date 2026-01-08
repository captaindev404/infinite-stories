# Proposal: Limit Initial Release Languages

## Summary
Restrict the initial App Store release to English and French only, while preserving all existing language translations in the codebase for future releases.

## Motivation
- **Simplified testing**: Two languages are easier to thoroughly test and validate
- **Faster time to market**: Reduces QA scope for initial release
- **Quality focus**: Ensures excellent experience in supported languages before expanding
- **Lower risk**: Smaller surface area for localization bugs in v1.0
- **Translations preserved**: Spanish, German, and Italian remain in codebase for future versions

## Current State Analysis

### What Exists
- **UI Localization**: 5 languages (en, es, fr, de, it) via String Catalogs
  - `Localizable.xcstrings` - ~330 UI strings translated
  - `InfoPlist.xcstrings` - System strings localized
- **Story Language**: 5 languages available in `AppSettings.availableLanguages`
- **UI Language Override**: `LocalizationManager.UILanguage` enum with all 5 + system
- **PromptLocalizer**: Prompt templates for all 5 languages
- **Backend**: Story generation supports all 5 languages

### What Needs to Change

| Component | Current | Target | Approach |
|-----------|---------|--------|----------|
| Story language picker | 5 languages | 2 (en, fr) | Filter `availableLanguages` |
| UI language picker | 5 + system | 2 + system | Filter `UILanguage.allCases` |
| Default language fallback | English | English | No change |
| String Catalogs | 5 languages | Keep all 5 | No deletion |
| PromptLocalizer | 5 languages | Keep all 5 | No deletion |
| Backend API | 5 languages | Keep all 5 | No change |

## Scope

### In Scope
1. Filter story language picker to show only English and French
2. Filter UI language picker to show only English, French, and System
3. Update default language detection to map unsupported languages to English
4. Update ios-localization spec to document phased release strategy
5. Ensure stories are generated in the correctly selected language

### Out of Scope
- Deleting any existing translations
- Modifying String Catalogs content
- Changing backend language support
- Removing PromptLocalizer templates
- Modifying audio voice options (should align with language support)

## Implementation Approach

### Option A: Filter at Display Level (Recommended)
- Create `releasedLanguages` subset that filters displayed options
- Single constant change enables future languages
- Zero risk of losing translation work
- Minimal code changes

### Option B: Feature Flag
- Add feature flag for each language
- More complex, unnecessary for binary on/off

**Decision**: Option A - simple, reversible, minimal code changes.

## Success Criteria
- Settings UI shows only English and French for story language
- Settings UI shows only System, English, and French for UI language
- Stories generate in selected language (verified via API calls)
- Spanish/German/Italian translations remain in codebase untouched
- App defaults to English for unsupported system languages
- Existing tests continue to pass

## Risks
- **Low**: Users expecting more languages may be disappointed
  - *Mitigation*: App Store description clearly lists supported languages
- **Low**: Developers might accidentally delete hidden translations
  - *Mitigation*: Document in code comments that translations are preserved

## Related Specs
- `ios-localization` - Will be modified to document phased release
- `prompt-management` - No changes needed, keeps all language templates

## Future Work
- Enable Spanish, German, Italian in subsequent releases
- Add more languages as translations are completed
- Consider language download on-demand for app size optimization
