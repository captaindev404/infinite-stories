## Context

InfiniteStories requires functioning `/privacy`, `/terms`, and `/support` pages for App Store submission. These URLs are already configured in App Store Connect metadata but were returning 404. The app targets children aged 3-10, requiring COPPA-compliant privacy disclosures.

**Stakeholders**: App Store Review team, parents/users, legal compliance
**Constraints**: Pages must be static/SSG, no auth required, must be COPPA-compliant, must support EN/FR locales

## Goals / Non-Goals

**Goals:**
- Provide live, accessible privacy policy at `/[locale]/privacy`
- Provide live, accessible terms of service at `/[locale]/terms`
- Provide live, accessible support page at `/[locale]/support`
- COPPA compliance covering OpenAI API data processing
- FR/EN bilingual support using Next.js App Router locale routing
- Shared design language with landing page

**Non-Goals:**
- Dynamic content management (pages are static)
- User authentication on public pages
- Cookie consent banners (no tracking cookies used)

## Decisions

### Decision 1: Static pages in Next.js App Router with locale routing

**What**: Implement pages as server-rendered Next.js pages under `app/[locale]/` path segments with a simple `lib/i18n.ts` dictionary.

**Why**:
- No external i18n library needed for 2 locales
- SSG/SSR provides fast loading and SEO
- Path-based routing (`/en/privacy`, `/fr/privacy`) is clean and crawlable

**Alternatives considered**:
- Separate static HTML files: Rejected, no shared layout/styling
- External CMS: Overkill for 3 legal pages

### Decision 2: COPPA-compliant privacy policy with AI disclosure

**What**: Privacy policy explicitly covers: no data collection from children, parental management model, OpenAI API processing disclosure, Cloudflare R2 storage, account deletion.

**Why**: Apple requires COPPA compliance for apps targeting children. OpenAI data processing must be disclosed per Apple guidelines 5.1.1.

### Decision 3: Shared design with landing page

**What**: Legal and support pages use the same color palette (purple/gold/midnight), typography, and layout structure as the landing page.

**Why**: Brand consistency across all public-facing pages.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Privacy policy needs legal review | Template follows standard COPPA patterns; flag for legal review before App Store submission |
| Translation accuracy | French translations are AI-generated; should be reviewed by native speaker |
| URL structure change (from `/privacy` to `/en/privacy`) | Root `/` redirects to `/en`, old paths handled by locale layout |
