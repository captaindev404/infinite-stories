---
stepsCompleted: [1, 2, 3, 4, 7, 8, 9, 10, 11]
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-infinite-stories-content-generator-2026-01-08.md
  - _bmad-output/analysis/brainstorming-session-2026-01-08.md
documentCounts:
  briefs: 1
  research: 0
  brainstorming: 1
  projectDocs: 0
workflowType: 'prd'
lastStep: 11
date: 2026-01-09
skippedSteps: [5, 6]
workflowComplete: true
completedAt: 2026-01-09
---

# Product Requirements Document - infinite-stories-content-generator

**Author:** Bro
**Date:** 2026-01-09

## Executive Summary

**infinite-stories-content-generator** is a programmatic content factory that gives a solo app developer leverage on video ad production. It transforms a single brief into 10 TikTok ad variations — combining AI avatar testimonials with magical B-roll from the InfiniteStories iOS app.

The core insight driving this tool: **The ads shouldn't market the app — they should BE the product experience.** Rather than explaining what InfiniteStories does, the ads show the magic between parent and child — a taste of infinite bedtime stories.

**The Problem:** Solo founders building consumer apps face an impossible trade-off: scale content creation for growth, or focus on product development. Manual video ad creation is time-intensive, expensive when outsourced, and doesn't support the iteration velocity needed for TikTok's algorithm-driven discovery.

**The Solution:** A custom-built tool that enables 1 brief → 10 video variations, with cost tracking and budget controls — designed specifically for InfiniteStories marketing at solo founder economics.

### What Makes This Special

| Differentiator | Why It Matters |
|----------------|----------------|
| **The ad IS the product** | Shows the magic, doesn't just describe it |
| **Programmatic, not manual** | 1 brief → 10 videos, scalable without team |
| **App-native content** | Repurposed illustrations and scenes from InfiniteStories |
| **Solo founder leverage** | Budget for tokens + servers, not agencies |

## Project Classification

**Technical Type:** Web Application (Telegram-style chat UX)
**Domain:** General (Media/Marketing Tooling)
**Complexity:** Low
**Project Context:** Greenfield - new project

## Success Criteria

### User Success

Success is measured by **iteration velocity** — the ability to rapidly test ad hypotheses and find the path to profitable ads.

| Metric | Target | Why It Matters |
|--------|--------|----------------|
| **Path to profitable ads** | Find 1+ winning formula | The discovery journey, not just one win |
| **Hypothesis testing speed** | Try idea → see results → iterate | Fast feedback loops enable learning |
| **Ads ready to deploy** | Videos ready even if imperfect | Iteration capability is the game changer |

**The Aha Moment:** Seeing 10 ad variations ready to deploy from a single brief — knowing you can iterate if they don't work.

### Business Success

| Timeframe | Success Metric |
|-----------|----------------|
| **3 months** | Found 1 profitable ad formula |
| **12 months** | Sustainable download growth from profitable ads |

**North Star Metric:** ROAS > 1
- $1 spent on ads generates more than $1 in net revenue
- Net = after App Store commission, infrastructure costs, AI generation costs

### Technical Success

| Requirement | Target | Notes |
|-------------|--------|-------|
| **Generation reliability** | >95% success rate | No failed generations |
| **Generation speed** | <5 minutes per ad | Fast enough for rapid iteration |
| **Cost visibility** | Real-time tracking | Token consumption + total cost per video |
| **Quality assurance** | Manual review (MVP) | Flag videos with visual artifacts (incoherences, 6-finger hands) |

**Dealbreaker:** Visual artifacts that make ads unusable (AI-generated incoherences)

### Measurable Outcomes

- **Weekly:** Generate 10-25 ad variations
- **Monthly:** 50-100 videos at $1-5 each
- **Quarterly:** Identify 1+ profitable ad formula
- **Annually:** 10,000+ app downloads from paid acquisition

## Product Scope

### MVP - Minimum Viable Product

Core capabilities to prove the concept:

1. **Brief → Videos Pipeline**
   - Single brief input → 1-10 video variations output
   - Telegram-style chat UX for brief creation

2. **AI Avatar Testimonials**
   - Parent persona avatars (diverse demographics)
   - UGC-style testimonial scripts

3. **B-roll Integration**
   - Pull magical content from InfiniteStories app
   - Story illustrations, bedtime scenes, parent-child moments

4. **Real-time Cost Tracking**
   - Token consumption per generation
   - Total cost per video

**Not in MVP:** Quality flagging system (manual review), B-roll library, batch generation

### Growth Features (Post-MVP)

| Feature | Value |
|---------|-------|
| **B-roll Library** | Reuse across ads, reduce regeneration costs |
| **Multiple Avatar Providers** | Veo3, Synthesia, etc. for variety/cost optimization |
| **Batch Generation** | Schedule and queue multiple briefs |

### Vision (Future)

- **AI Learns Winning Patterns** — System identifies what makes ads perform
- **Auto-optimization** — Automatically generate variations of winning formulas
- **Multi-platform** — Instagram Reels, YouTube Shorts (stretch)

## User Journeys

### Journey 1: Bro — From Trend to Winning Ad Formula (Primary User)

Bro is scrolling TikTok when a new trend catches his eye — a format that could work perfectly for InfiniteStories. The creative spark hits. Instead of spending the next 3 hours manually building one video, he opens the content generator and starts brainstorming in chat.

In 10 minutes, he's written a brief: the hook, the parent persona, the emotional angle, the B-roll scenes he wants. The tool churns out 10 variations. He reviews them, flags 2 with weird visual artifacts, and selects 3 promising ones. Upload to TikTok Ads. Done.

Over the next 48 hours, he watches the metrics. One ad tanks — he kills it. Two show promise: good CTR, some installs. The breakthrough comes when one ad starts driving not just installs, but **in-app purchases**. He takes that winner and feeds it back to the tool: "Give me 5 variations of this."

A month later, Bro's reality has transformed. He's creating ads at monumental scale, testing hypotheses as fast as they come to him. The flywheel is spinning: trend → brief → variations → test → iterate on winners. He's found 3 profitable ad formulas and his CAC is finally sustainable.

**Edge Cases:**
- **All 10 duds:** Tweak the brief and regenerate (not start fresh)
- **Iterate on winner:** Adjust all parameters (hook, avatar, B-roll) to create slightly different variants

### Journey 2: Future Assistant — Template-Driven Ad Production (Growth Phase)

Alex is a freelance VA hired by Bro to scale ad production. Bro has identified 3 winning ad formulas and created templates for each: "Tired Parent," "Magic Moment," and "Bedtime Struggle." Alex's job is to keep the content pipeline full.

Every Monday, Alex opens the content generator and picks a template. The brief structure is pre-filled — hook pattern, avatar type, B-roll scenes. Alex adds small variations: a different parent persona, a tweak to the opening line, a new bedtime scenario. Generate 10 variations. Review for quality (flag artifacts). Select the best 3-4 and upload to TikTok Ads with standard campaign settings.

By Friday, Alex has produced 30 ad variations from the 3 templates. Bro reviews the weekly performance data, identifies a new winner, and creates a 4th template. Alex adds it to the rotation.

The system runs itself: Bro does strategy (templates, winners), Alex does execution (variations, uploads).

### Journey Requirements Summary

| Capability | Journey Source | Phase |
|------------|---------------|-------|
| **Chat-based brief creation** | Journey 1 | MVP |
| **Batch generation (10 variations)** | Journey 1 | MVP |
| **Quality review/flagging** | Journey 1, 2 | MVP (manual) |
| **Brief tweaking + regenerate** | Journey 1 (edge case) | MVP |
| **"Iterate on winner" workflow** | Journey 1 | MVP |
| **Real-time cost tracking** | Journey 1 | MVP |
| **Template system** | Journey 2 | Growth |
| **Multi-user access** | Journey 2 | Growth |
| **Production tracking** | Journey 2 | Growth |

## Web Application Specific Requirements

### Tech Stack (User Familiar)

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Framework** | Next.js | SSR/SPA hybrid, API routes, file-based routing |
| **UI Components** | ShadCN | Pre-built accessible components, Tailwind-based |
| **ORM** | Prisma | Type-safe database access, migrations |
| **Database** | PostgreSQL | Relational data (briefs, generations, costs) |
| **Media Storage** | Cloudflare R2 | Generated videos, B-roll assets, avatars |

### Browser Support

| Browser | Support Level |
|---------|---------------|
| Chrome/Firefox/Safari/Edge (latest) | Full |
| IE11 / Legacy | Not supported |

### Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Rendering** | Next.js App Router | Familiar stack, server components |
| **Real-time** | Polling | Simpler than WebSockets for MVP |
| **SEO** | Not required | Internal tool |
| **Accessibility** | Basic | Single user |
| **AI Providers** | Provider-agnostic | Support Veo3, Nano Banana, OpenAI, etc. |

### Data Model (Prisma)

| Entity | Purpose | Key Design |
|--------|---------|------------|
| **Brief** | User input | Free text → AI-parsed JSON (`rawInput` + `parsedData`) |
| **Generation** | Batch run | Parent-child tracking for "iterate on winner" |
| **Video** | Individual output | Store everything in `generationParams` JSON |
| **CostLog** | Granular tracking | Provider-agnostic (serviceType, provider, operation) |
| **Template** | Winning formulas | Growth phase, links to source Brief |

### Provider Abstraction Layer

| Service Type | Potential Providers |
|--------------|---------------------|
| **Script Generation** | OpenAI, Claude, Gemini |
| **Avatar/Video** | Veo3, Nano Banana |
| **B-roll Generation** | Sora, Runway, Pika |
| **Storage** | Cloudflare R2 |

### External Integrations

| Service | Purpose | Phase |
|---------|---------|-------|
| **AI Provider (TBD)** | Avatar + video generation | MVP |
| **LLM Provider (TBD)** | Script generation, JSON parsing | MVP |
| **InfiniteStories API** | Pull B-roll content | MVP |
| **Cloudflare R2** | Store generated videos | MVP |
| **TikTok Ads API** | Upload integration | Growth |

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Problem-Solving MVP
- Solve the core problem (scale ad production) with minimal features
- Fastest path to validated learning: 1 brief → 10 videos → test → iterate

**Resource Requirements:**
- Solo developer (you)
- Familiar stack: Next.js, ShadCN, Prisma, PostgreSQL, R2
- No external team dependencies for MVP

### MVP Feature Set (Phase 1)

**Core User Journey Supported:** Journey 1 — Trend to Winning Ad Formula

**Must-Have Capabilities:**

| Capability | Description | Rationale |
|------------|-------------|-----------|
| **Chat-based brief creation** | Free text → AI-parsed JSON | Core input method |
| **Batch generation** | 1 brief → 10 video variations | Core value proposition |
| **AI avatar testimonials** | Parent personas, UGC-style | The "face" of the ad |
| **B-roll integration** | Pull from InfiniteStories | The "magic" of the ad |
| **Real-time cost tracking** | Per-video and total costs | Budget control |
| **Brief tweaking + regenerate** | Edit and retry | Handle failures |
| **Iterate on winner** | Generate variations from winning video | Scale winners |
| **Manual quality review** | Flag artifacts, approve/reject | Quality gate |

**Explicitly NOT in MVP:**
- Quality flagging system (automated)
- B-roll library (reuse assets)
- Template system
- Multi-user access
- Batch scheduling
- TikTok Ads API integration

### Post-MVP Features

**Phase 2: Growth**

| Feature | Value | Trigger |
|---------|-------|---------|
| **B-roll Library** | Reuse assets, reduce regeneration costs | After 50+ videos generated |
| **Template System** | Save winning formulas for reuse | After 3+ winning patterns found |
| **Multiple Avatar Providers** | Veo3, Nano Banana options | When evaluating cost/quality tradeoffs |
| **Multi-user Access** | Onboard VA/contractor | When scaling beyond solo capacity |
| **Batch Generation** | Schedule multiple briefs | When production volume increases |

**Phase 3: Vision**

| Feature | Value | Trigger |
|---------|-------|---------|
| **AI Learns Winning Patterns** | System identifies what performs | After 100+ ads with performance data |
| **Auto-optimization** | Generate variations of winners automatically | Proven winning formulas exist |
| **TikTok Ads Integration** | Direct upload from tool | When manual upload becomes bottleneck |

### Risk Mitigation Strategy

**Technical Risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| AI visual artifacts (6 fingers, etc.) | High | Medium | Manual review, provider-agnostic design |
| Provider API changes/limits | Medium | High | Abstraction layer, multiple provider options |
| Generation failures | Medium | Low | Retry logic, clear error states |

**Market Risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Ads don't convert | Medium | High | Fast iteration, low cost per test ($1-5) |
| TikTok algorithm changes | Medium | Medium | Focus on content quality, not hacks |

**Resource Risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Solo developer burnout | Medium | High | Familiar stack, lean MVP, no over-engineering |
| Budget constraints | Low | Medium | Real-time cost tracking, budget caps |

### Minimum Viable Launch Criteria

**MVP is ready when:**
- [ ] Can write a brief in chat and get parsed JSON
- [ ] Can generate 10 video variations from one brief
- [ ] Can view generated videos with cost breakdown
- [ ] Can iterate on a winning video to create variations
- [ ] Generation completes in <5 minutes
- [ ] >95% generation success rate

## Functional Requirements

### Brief Creation & Management

- FR1: User can write a brief in natural language via chat interface
- FR2: System can parse natural language brief into structured JSON (hook, persona, emotion, B-roll tags)
- FR3: User can view the parsed structure of their brief
- FR4: User can edit/tweak an existing brief and trigger regeneration
- FR5: User can view history of all briefs created
- FR6: User can duplicate an existing brief as starting point for a new one

### Video Generation

- FR7: User can trigger generation of 1-10 video variations from a single brief
- FR8: System can generate AI avatar testimonial content based on brief persona
- FR9: System can integrate B-roll content from InfiniteStories app assets
- FR10: System can compose avatar testimonial with B-roll into final video
- FR11: User can view generation progress/status while videos are being created
- FR12: System can store generated videos in cloud storage (R2)

### Cost Tracking & Budgeting

- FR13: System can track cost per video in real-time during generation
- FR14: System can track token consumption per AI provider operation
- FR15: User can view cost breakdown per video (by service type and provider)
- FR16: User can view total cost per generation batch
- FR17: User can view aggregate cost statistics (daily, weekly, monthly)

### Video Review & Quality

- FR18: User can preview each generated video
- FR19: User can flag a video as having quality issues (artifacts, incoherences)
- FR20: User can add a note explaining why a video was flagged
- FR21: User can mark a video as approved/passed quality review
- FR22: User can filter videos by quality status (pending, passed, flagged)

### Iteration & Variations

- FR23: User can select a winning video and trigger "iterate on winner" workflow
- FR24: System can generate variations of a selected video (adjusting hook, avatar, B-roll)
- FR25: System can track parent-child relationship between generations
- FR26: User can view the lineage/history of iterations for any video

### Video Library & Output

- FR27: User can view all generated videos in a gallery/list view
- FR28: User can filter videos by brief, generation batch, date, or status
- FR29: User can download individual videos for upload to TikTok
- FR30: User can view video metadata (cost, generation params, provider used)
- FR31: User can delete videos that are no longer needed

## Non-Functional Requirements

### Performance

| Requirement | Target | Measurement |
|-------------|--------|-------------|
| **Video generation time** | <5 minutes per video | Time from brief submission to video ready |
| **UI responsiveness** | <500ms for user actions | Page loads, button clicks, navigation |
| **Poll interval** | 5 seconds | Generation status updates |
| **Video preview load** | <2 seconds | Time to start video playback |

### Reliability

| Requirement | Target | Measurement |
|-------------|--------|-------------|
| **Generation success rate** | >95% | Completed videos / attempted generations |
| **Data persistence** | Zero data loss | Briefs, videos, costs always saved |
| **Error recovery** | Graceful degradation | Failed generations don't crash app |
| **Retry logic** | 3 attempts with backoff | For transient AI provider failures |

### Security

| Requirement | Description |
|-------------|-------------|
| **API key storage** | All AI provider keys stored in environment variables, never in code |
| **Database access** | Connection via Prisma with parameterized queries (no SQL injection) |
| **R2 access** | Signed URLs for video access, not public buckets |
| **HTTPS only** | All traffic encrypted in transit |

### Integration

| Requirement | Target | Notes |
|-------------|--------|-------|
| **Provider abstraction** | Swap providers without code changes | Via provider interface pattern |
| **API timeout handling** | 30 second timeout per AI call | With retry logic |
| **Rate limit handling** | Respect provider limits | Queue and throttle if needed |
| **InfiniteStories API** | Authenticated access to B-roll assets | Via existing API keys |
