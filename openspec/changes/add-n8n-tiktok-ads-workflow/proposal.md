# Change: Add n8n TikTok UGC Ads Workflow

## Why

InfiniteStories needs a scalable, automated solution to generate TikTok UGC-style promotional videos. Manual ad creation is time-consuming and expensive. By leveraging the same AI models used in the app backend (OpenAI) combined with Replicate for video generation, we can produce high-quality ads quickly with simplified billing.

## What Changes

- Add new `n8n-workflows/` directory for automation workflows
- Create `tiktok-ugc-ads-generator.json` - Main n8n workflow for generating TikTok ads
- Create `README.md` - Visual documentation with architecture diagrams
- Integrate with:
  - OpenAI `gpt-5-mini` for script generation (same as story generation)
  - OpenAI `gpt-4o-mini-tts` for voiceover synthesis
  - Replicate `flux-1.1-pro` for image generation
  - Replicate `minimax/video-01` or `kling-v1.6-pro` for video generation

## Impact

- Affected specs: None (new capability)
- Affected code: New `n8n-workflows/` directory
- New external dependencies: Replicate API
- Infrastructure: Requires n8n instance (self-hosted or cloud)
