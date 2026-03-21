## Why

Apple requires a functioning Support URL and Privacy Policy URL before an app can be submitted for review. These URLs are already pushed to App Store Connect metadata for InfiniteStories v1.0 (`/support` and `/privacy` on `infinite-stories-web.captaindev.io`), but the pages don't exist yet — they return 404. Without them, the app will be rejected during review.

Additionally, since InfiniteStories targets children aged 3-10, the privacy policy must be COPPA-compliant and disclose OpenAI API data processing, which is a hard requirement for the Kids category on the App Store.

## What Changes

- Add a `/support` page with FAQ, contact info, troubleshooting, and help resources
- Add a `/privacy` page with a full privacy policy covering:
  - COPPA compliance (children under 13)
  - OpenAI API data processing disclosure (stories, audio, illustrations)
  - Data collection and retention practices
  - Parental controls and consent
  - No ads, no tracking, no personal data collection from children
- Add a shared layout for public-facing pages (consistent header/footer/branding)
- Pages must be static/SSG (no auth required, fast loading, SEO-friendly)

## Capabilities

### New Capabilities
- `public-pages`: Shared layout, header, footer, and styling for public-facing web pages on the Next.js backend. Provides the foundation for support, privacy, and any future marketing pages.

### Modified Capabilities
- `app-store-metadata`: URLs in App Store Connect metadata (`supportUrl`, `privacyPolicyUrl`) now resolve to live pages instead of 404.

## Impact

- **Backend** (`infinite-stories-backend/`): New Next.js App Router pages at `/app/support/page.tsx` and `/app/privacy/page.tsx`, plus a shared layout component
- **Styling**: Tailwind CSS (already configured), Geist fonts (already loaded)
- **Deployment**: Pages deploy automatically via existing Vercel pipeline — no infra changes
- **iOS app**: No changes — URLs are already configured in ASC metadata
- **Dependencies**: None — uses existing Next.js + Tailwind stack
