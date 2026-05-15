# Screenshot Verification Checklist — App Store Submission

Run this checklist before uploading screenshots to App Store Connect. Each item must pass for **both** locales (`screenshots/en/` and `screenshots/fr/`). Re-capture any screenshot that fails. Final filenames must match what's already on disk (Apple does not require new names just because content changed).

## ⚠️ Known Structural Issue — Locale Cross-Contamination

The current screenshot set was generated using **a single user account**, which means user-generated content (hero names, story titles, custom event titles, the user's preferred app language at signup, persisted story preferences) is identical across `screenshots/en/` and `screenshots/fr/`.

In practice: **the English screenshots contain French user content** (and/or vice-versa). Examples of what bleeds across locales:

- Hero names entered by the user
- Custom event titles and descriptions (e.g., "Première journée d'école" appearing in EN screenshots)
- Story titles previously generated
- The app-language preference if it was set on the account before capture

This is an App Store rejection risk: Apple expects locale-appropriate content in each locale's screenshot set.

### Resolution: Per-locale capture accounts

The screenshot generation pipeline must be reworked so each locale has its **own demo account** seeded in that locale. Minimum requirements:

- [ ] One dedicated account per supported locale (currently `en`, `fr`)
- [ ] Each account is seeded server-side with locale-appropriate hero name, custom event(s), and at least one generated story whose title/content is in that locale
- [ ] App language preference set to match the locale before capture
- [ ] Device language and region set to match the locale before capture
- [ ] Capture script logs into the correct account based on the target locale, not a shared one
- [ ] No manual data entry during capture (deterministic seeds → reproducible screenshots)

Until this is in place, **task 5.2 cannot be marked complete** — every existing screenshot fails the cross-locale check below.

### Cross-locale check (applies to every screenshot)

- [ ] Every user-visible string in `screenshots/en/*.png` is in English (including hero names, custom event titles, story titles)
- [ ] Every user-visible string in `screenshots/fr/*.png` is in French (including hero names, custom event titles, story titles)
- [ ] No French strings appear in any EN file; no English strings appear in any FR file

---

## Required Re-captures for the Current Submission

The screenshots below must be re-captured because they predate the App Store approval fixes shipped in this change. Re-captures must use the **per-locale accounts** described above, not the shared legacy account.

### 1. Settings — must show new sections

**Files:** `screenshots/en/05_settings.png`, `screenshots/fr/05_settings.png`

The current capture is scrolled to the top and shows only Theme, App Language, and Story Preferences. The Privacy/Terms links and Delete Account button (added in this change) are below the fold and **do not appear**. Re-capture so the screenshot includes:

- [ ] **About section** is visible with both **Privacy Policy** and **Terms of Service** links
- [ ] **Advanced section** is visible with the **Delete Account** button (red, destructive style)
- [ ] If a single screenshot can't fit both sections, capture a second screenshot (`05b_settings_about_advanced.png`) scrolled to those sections and include it in the App Store Connect upload set

> Tip: use a tall device frame (iPhone 15 Pro Max) and reduce dynamic type to default — both Privacy/Terms and Delete Account should fit in one scroll position on that device.

### 2. Custom Events — must not show "coming soon"

**Files:** `screenshots/en/09_custom_events.png`, `screenshots/fr/09_custom_events.png`

- [ ] No occurrence of "coming soon" / "bientôt disponible" / pictogram placeholder text anywhere in the frame
- [ ] No path visible to the (now-gated) PictogramGenerationView

The current English capture already looks clean. Re-verify the French capture against the same criteria.

### 3. Illustration carousel placeholder — must show loading state

If any screenshot includes the illustration carousel in a placeholder state (e.g., during story playback before illustrations finish loading), confirm:

- [ ] Placeholder shows a **`ProgressView`** with the text "Generating illustration..." (EN) / "Génération de l'illustration..." (FR)
- [ ] **No occurrence** of "Illustration Coming Soon" / "Illustration à venir"

Files most likely affected: `08_audio_player.png`. Inspect; re-capture only if the placeholder is visible.

## Global Verification (all screenshots, all locales)

Apply these checks to **every** file under `screenshots/en/` and `screenshots/fr/`:

- [ ] No status-bar artifacts (charging icon, low-battery, debug overlay, ringer-silent indicator)
- [ ] Time in status bar normalized (Apple convention: `9:41` — or at minimum consistent across the set)
- [ ] No personally identifiable information (real names, real photos) anywhere
- [ ] No "coming soon", "TODO", "[placeholder]", "Lorem ipsum", or other unfinished-state text
- [ ] No debug-only UI (developer settings, in-app debug overlays, log panels)
- [ ] FR screenshots actually render French strings — not English fallbacks
- [ ] Touch targets and text are legible at the App Store thumbnail size (~250×440 px)
- [ ] All screenshots use the same device frame size (mixing 6.7" and 6.1" in one upload set is rejected)
- [ ] No third-party trademarks, app icons, or brand logos visible
- [ ] Hero / story content shown is generic and family-friendly (no test names like "asdf")

## Locale Coverage Sanity Check

Released languages for v1.0.x are **English and French only** (`AppSettings.releasedLanguageCodes`). Screenshot folders must mirror this:

- [ ] `screenshots/en/` exists and is complete
- [ ] `screenshots/fr/` exists and is complete
- [ ] No screenshots for Spanish/German/Italian uploaded to App Store Connect for this version

## After Re-capturing

1. Run the **Global Verification** checklist against every replaced file.
2. Diff filenames against the previous submission — make sure no required slot is empty.
3. Update App Store Connect: replace files in-place, preserve display order.
4. Tick task 5.2 in `openspec/changes/app-store-approval-fixes/tasks.md` once all boxes above are checked.
