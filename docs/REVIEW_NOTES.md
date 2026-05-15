# App Store Review Notes — InfiniteStories

Paste the relevant section into the **Review Notes** field in App Store Connect when submitting a new version. Replace placeholders in `[BRACKETS]` before submission. Confirm the demo account is active and that the backend environment it points to is reachable.

---

## Demo Account

- **Email:** `[DEMO_EMAIL]`
- **Password:** `[DEMO_PASSWORD]`
- **Backend environment:** Production (`https://api.infinitestories.app`)
- **Notes for reviewer:** Account is pre-seeded with one hero and at least one generated story so reviewers can exercise all flows without waiting for AI generation. Do not delete this account between submissions — re-seed if needed.

> ⚠️ Before submitting: log in with these credentials on a clean device, confirm the seeded hero/story are present, and that the account is **not** scheduled for deletion.

## Supported Languages (v1.0.x)

This release supports **English and French** only. Spanish, German, and Italian are scheduled for a future release. Set the device language to English or French to evaluate localized UI; other languages fall back to English.

## App Overview

InfiniteStories is a children's bedtime-story app. Parents create a "hero" (a child character with traits and appearance), pick or define a story event, and the app generates a personalized, narrated audio story with synchronized AI illustrations. All generation runs server-side via the InfiniteStories backend.

The app **requires an active internet connection**. If offline, the app shows a "Network Required" screen and blocks generation — this is by design, not a bug.

## Test Flows

Each flow should take 2–4 minutes. Run them in order on the demo account.

### 1. Sign In
1. Launch the app.
2. On the authentication screen, tap **Sign In**.
3. Enter the demo email and password above.
4. **Expected:** Land on the Home tab with the seeded hero visible.

### 2. Hero Creation
1. From the Home tab, tap the floating **+** action button → **Create Hero** (or the Heroes tab → **+**).
2. Step through the wizard: Name → Primary Trait → Secondary Trait → Appearance → Preview.
3. Tap **Create Hero**.
4. **Expected:** A network call generates the hero avatar. The new hero appears in the Heroes tab.

### 3. Story Generation & Audio Playback
1. From the Home tab, tap the floating action button → **Generate Story**.
2. Pick the demo hero, then pick any built-in story event (e.g., "Adventure in the Forest").
3. Wait for generation (~30–60 seconds — story text, audio, and illustrations are generated server-side).
4. When the player opens, tap **Play**.
5. **Expected:** Audio plays with lock-screen controls. Illustrations advance in sync with the audio. Playback continues in the background and on the lock screen.

### 4. Custom Event Creation
1. Tap the floating action button → **Custom Events** → **+**.
2. Enter a title (e.g., "Visit to Grandma") and a short description.
3. Tap the AI enhancement button to expand the description, then **Save**.
4. **Expected:** Custom event saved and selectable when generating a story.

### 5. Account Deletion (Apple-required flow)
1. Open the **Settings** tab → scroll to the **Advanced** section.
2. Tap **Delete Account** (red).
3. Read the first confirmation alert, then tap **Continue**.
4. On the second confirmation, tap **Delete My Account** (destructive).
5. **Expected:** The backend returns 204, local data is erased, and the app navigates back to the authentication screen. The demo email can no longer sign in.

> ⚠️ **Reviewer:** Please **do not run flow 5** against the production demo account unless you intend to re-create it. A dedicated single-use deletion-test account is provided below if you wish to verify the flow end-to-end.

- **Deletion-test email:** `[DELETION_TEST_EMAIL]`
- **Deletion-test password:** `[DELETION_TEST_PASSWORD]`

### 6. Privacy Policy & Terms of Service
1. Open the **Settings** tab → scroll to the **About** section.
2. Tap **Privacy Policy** → opens `https://www.infinitestories.app/privacy` in Safari.
3. Return to the app, tap **Terms of Service** → opens `https://www.infinitestories.app/terms` in Safari.
4. **Expected:** Both pages load with the current published policy/terms.

## Content Safety

All story content is generated through a multi-language child-safety content filter (`ContentPolicyFilter`) before being returned to the device. Voices and prompts are tuned for ages 4–10. There is no user-to-user communication, no chat, no UGC sharing, and no in-app browser for arbitrary URLs.

## Known Limitations in This Release

- Pictogram generation for custom events is hidden in v1.0.x (planned for a future release).
- The "Favorite Stories" section in Reading Journey is hidden in v1.0.x pending a backend endpoint.
- Network connectivity is required — there is no offline mode.

## Contact

- **Submission contact:** `[CONTACT_NAME]` — `[CONTACT_EMAIL]`
- **Backend status / outage contact:** `[OPS_CONTACT_EMAIL]`
