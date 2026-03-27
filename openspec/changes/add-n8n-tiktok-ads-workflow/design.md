# Design: n8n TikTok UGC Ads Workflow

## Context

InfiniteStories is a children's bedtime story app that needs promotional content for TikTok. The team wants to leverage existing AI infrastructure (OpenAI models) while adding video generation capabilities. n8n was chosen as the workflow automation platform for its flexibility and self-hosting options.

## Goals / Non-Goals

**Goals:**
- Automate TikTok ad generation from a simple briefing input
- Maintain consistency with backend AI models (OpenAI)
- Support multiple output modes for flexibility
- Simplify billing through Replicate consolidation
- Produce TikTok-optimized 9:16 vertical videos

**Non-Goals:**
- Direct TikTok posting (handled separately)
- A/B testing infrastructure
- Real-time video editing
- User-facing interface (n8n internal only)

## Decisions

### Decision 1: Use n8n for workflow orchestration
- **What**: n8n handles the entire pipeline from briefing to video output
- **Why**: Visual workflow editor, self-hostable, good API integration support
- **Alternatives**: Zapier (expensive), custom code (maintenance overhead), Make (less flexible)

### Decision 2: OpenAI for script and audio generation
- **What**: Use `gpt-5-mini` for scripts, `gpt-4o-mini-tts` for voiceover
- **Why**: Consistency with backend models, proven quality, existing billing relationship
- **Alternatives**: Claude (no TTS), ElevenLabs (separate billing), Anthropic (no audio)

### Decision 3: Replicate for image and video generation
- **What**: Use Replicate API with `flux-1.1-pro` for images, `minimax/video-01` for video
- **Why**: Single billing platform for compute-heavy media generation, model flexibility
- **Alternatives**:
  - DALL-E 3 (expensive at scale)
  - Runway (separate subscription)
  - Pika (less API-friendly)

### Decision 4: UGC-style script structure
- **What**: HOOK (0-3s) -> PROBLEM (3-8s) -> DISCOVERY (8-15s) -> BENEFITS (15-25s) -> CTA (25-30s)
- **Why**: Proven TikTok format for engagement, fits platform algorithm preferences
- **Alternatives**: Testimonial format, demo format (less engaging for app promotion)

### Decision 5: Conditional output modes
- **What**: 4 output modes (script_only, script_audio, script_images, full_video)
- **Why**: Allow iterative review, cost control, faster turnaround for script-only needs
- **Alternatives**: Single full output (wastes resources if only script needed)

## Technical Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        n8n WORKFLOW                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐    ┌──────────────┐    ┌────────────────────────┐ │
│  │  Form    │───▶│   OpenAI     │───▶│    Conditional         │ │
│  │ Trigger  │    │  gpt-5-mini  │    │    Branching           │ │
│  └──────────┘    │   (Script)   │    └──────────┬─────────────┘ │
│                  └──────────────┘               │               │
│                                                 ▼               │
│                  ┌──────────────────────────────┴─────────┐     │
│                  │                                        │     │
│         ┌────────▼────────┐  ┌─────────▼─────────┐       │     │
│         │ OpenAI TTS      │  │ Replicate         │       │     │
│         │ gpt-4o-mini-tts │  │ flux-1.1-pro      │       │     │
│         │ (Audio)         │  │ (Images x5)       │       │     │
│         └────────┬────────┘  └─────────┬─────────┘       │     │
│                  │                     │                  │     │
│                  └──────────┬──────────┘                  │     │
│                             ▼                             │     │
│                  ┌──────────────────────┐                │     │
│                  │ Replicate            │                │     │
│                  │ minimax/video-01     │                │     │
│                  │ (Video Assembly)     │                │     │
│                  └──────────┬───────────┘                │     │
│                             ▼                             │     │
│                  ┌──────────────────────┐                │     │
│                  │   JSON Response      │                │     │
│                  │   (All Assets)       │                │     │
│                  └──────────────────────┘                │     │
│                                                          │     │
└──────────────────────────────────────────────────────────┴─────┘
```

## API Models Reference

| Component | Provider | Model | Purpose |
|-----------|----------|-------|---------|
| Script | OpenAI | gpt-5-mini | UGC script generation |
| Audio | OpenAI | gpt-4o-mini-tts | Voiceover synthesis |
| Images | Replicate | flux-1.1-pro | Scene illustrations |
| Video | Replicate | minimax/video-01 | Video assembly |

## Risks / Trade-offs

- **Risk**: Replicate model availability/deprecation
  - Mitigation: Abstract model selection, easy to swap alternatives

- **Risk**: Cost overruns on full video generation
  - Mitigation: Output modes allow script-only for review before committing to video

- **Risk**: Video quality inconsistency
  - Mitigation: Use proven models, image-to-video ensures visual consistency

- **Trade-off**: Async polling vs webhooks for Replicate
  - Chose polling for simplicity; webhooks for production at scale

## Migration Plan

1. Deploy n8n instance
2. Configure API credentials
3. Import workflow JSON
4. Test with sample briefings
5. Create production briefing templates
6. Train team on workflow usage

## Open Questions

- Q1: Should we add automatic TikTok posting integration?
- Q2: Do we need A/B testing for different script styles?
- Q3: Should we support other platforms (Instagram Reels, YouTube Shorts)?
