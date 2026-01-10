# n8n Workflows - InfiniteStories Marketing Automation

This folder contains n8n workflows for automating marketing content creation for InfiniteStories.

## Available Workflows

| Workflow | File | Description | Cost/Run |
|----------|------|-------------|----------|
| Full Video Generator | `tiktok-ugc-ads-generator.json` | Complete video with voiceover | ~$2.85 |
| Script + Images | `tiktok-ugc-script-generator.json` | Script and images only | ~$2.10 |

---

## 1. TikTok UGC Ads Generator (Full Video)

**File:** `tiktok-ugc-ads-generator.json`

Generates TikTok-ready UGC (User Generated Content) style video ads from a simple briefing.

### Workflow Overview

```
Briefing Input -> AI Script Generation -> Scene Images -> Voiceover -> Video Assembly -> TikTok-Ready Video
```

### Features

- AI-generated UGC-style scripts (GPT-4o)
- Multi-language support (FR, EN, ES, DE, IT)
- DALL-E 3 scene image generation (9:16 vertical format)
- ElevenLabs voiceover synthesis
- Automatic video assembly with Shotstack
- TikTok-optimized output (1080p, 9:16, 30fps)

### Required Credentials

Configure these credentials in n8n before importing:

| Credential ID | Service | Required Scopes |
|--------------|---------|-----------------|
| `openai-credentials` | OpenAI API | GPT-4o, DALL-E 3 |
| `elevenlabs-api` | ElevenLabs | Text-to-Speech |
| `shotstack-api` | Shotstack | Video Rendering |
| `cloudinary-api` | Cloudinary | Asset Upload |

### API Endpoint

Once activated, the workflow exposes:

```
POST /webhook/generate-tiktok-ad
```

### Request Body

```json
{
  "product_name": "InfiniteStories",
  "target_audience": "Parents with children aged 2-10",
  "key_benefits": [
    "Personalized AI-generated bedtime stories",
    "Child becomes the hero of the story",
    "Beautiful illustrations synced with audio",
    "Multiple languages supported",
    "Safe content for children"
  ],
  "tone": "warm, authentic, relatable",
  "duration_seconds": 30,
  "language": "fr",
  "hook_type": "problem-solution",
  "cta": "Telecharge InfiniteStories maintenant!",
  "custom_instructions": "Focus on the magical bedtime routine"
}
```

### Request Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `product_name` | string | No | InfiniteStories | Product name |
| `target_audience` | string | No | Parents with children aged 2-10 | Target demographic |
| `key_benefits` | array | No | App default benefits | List of key selling points |
| `tone` | string | No | warm, authentic, relatable | Voice and style tone |
| `duration_seconds` | number | No | 30 | Target video duration |
| `language` | string | No | fr | Language code (fr/en/es/de/it) |
| `hook_type` | string | No | problem-solution | Hook style |
| `cta` | string | No | Telecharge InfiniteStories! | Call to action text |
| `custom_instructions` | string | No | "" | Additional creative direction |

### Hook Types

- `problem-solution` - Start with a relatable problem
- `question` - Open with an engaging question
- `story` - Begin with a mini-story
- `shocking-stat` - Lead with an attention-grabbing statistic
- `testimonial` - Start as a personal recommendation

### Response

```json
{
  "success": true,
  "video_url": "https://cdn.shotstack.io/...",
  "render_id": "abc123",
  "script": {
    "hook": "Vous cherchez comment endormir vos enfants facilement?",
    "cta": "Telecharge InfiniteStories maintenant!",
    "hashtags": ["parenting", "bedtimestories", "kidsapp"],
    "music_suggestion": "Soft acoustic, feel-good vibe",
    "scenes": [...]
  },
  "generated_assets": {
    "scene_images": [
      {
        "scene_number": 1,
        "image_url": "https://...",
        "duration": 5
      }
    ]
  },
  "metadata": {
    "product": "InfiniteStories",
    "language": "fr",
    "duration_seconds": 30,
    "generated_at": "2026-01-10T12:00:00.000Z"
  },
  "tiktok_ready": {
    "caption": "Vous cherchez comment endormir vos enfants facilement?\n\n#parenting #bedtimestories #kidsapp",
    "suggested_sounds": "Soft acoustic, feel-good vibe"
  }
}
```

### Example cURL Request

```bash
curl -X POST https://your-n8n-instance.com/webhook/generate-tiktok-ad \
  -H "Content-Type: application/json" \
  -d '{
    "product_name": "InfiniteStories",
    "target_audience": "Parents fatigues qui veulent des moments magiques avec leurs enfants",
    "key_benefits": [
      "Histoires personnalisees avec le prenom de votre enfant",
      "Votre enfant devient le heros",
      "Illustrations magnifiques synchronisees",
      "5 langues disponibles",
      "Contenu 100% adapte aux enfants"
    ],
    "tone": "authentique, chaleureux, comme une amie qui partage un bon plan",
    "duration_seconds": 30,
    "language": "fr",
    "hook_type": "problem-solution",
    "cta": "Telecharge InfiniteStories - Lien en bio!",
    "custom_instructions": "Mettre en avant le moment du coucher et la fatigue des parents"
  }'
```

### Installation

1. Open your n8n instance
2. Go to **Workflows** > **Import**
3. Upload `tiktok-ugc-ads-generator.json`
4. Configure the required credentials
5. Activate the workflow

### Estimated Costs per Video

| Service | Estimated Cost |
|---------|---------------|
| OpenAI GPT-4o (script) | ~$0.05 |
| OpenAI DALL-E 3 (images) | ~$0.40/image x 5 = $2.00 |
| ElevenLabs (voiceover) | ~$0.30 |
| Shotstack (rendering) | ~$0.50 |
| **Total** | **~$2.85/video** |

### Workflow Nodes Diagram

```
[Webhook] --> [Validate Input] --> [Generate Script (GPT-4o)]
                                          |
                    +---------------------+---------------------+
                    |                                           |
                    v                                           v
        [Split Scenes]                              [Select Voice]
              |                                           |
              v                                           v
    [Generate Image Prompts]                   [ElevenLabs TTS]
              |                                           |
              v                                           v
    [Generate Images (DALL-E)]                  [Upload Audio]
              |                                           |
              v                                           |
    [Collect Scene Data]                                  |
              |                                           |
              +-----------------> [Merge] <---------------+
                                    |
                                    v
                        [Shotstack Video Render]
                                    |
                                    v
                        [Poll Render Status]
                                    |
                                    v
                        [Return Video URL]
```

### Customization

#### Adding New Languages

Edit the `Select Voice by Language` node to add new ElevenLabs voice IDs:

```javascript
const voiceMap = {
  'fr': 'your-french-voice-id',
  'en': 'your-english-voice-id',
  // Add more languages
};
```

#### Changing Video Style

Modify the `Shotstack - Create Video` node to adjust:
- Transitions (`fade`, `slideLeft`, `zoom`, etc.)
- Effects (`zoomIn`, `slideRight`, etc.)
- Text overlays and positioning
- Output resolution and format

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Images not generating | Check OpenAI API quota and DALL-E 3 access |
| Voice sounds wrong | Verify ElevenLabs voice ID for the language |
| Video render fails | Check Shotstack API status and image URLs |
| Timeout errors | Increase n8n execution timeout settings |

---

## 2. TikTok UGC Script Generator (Simplified)

**File:** `tiktok-ugc-script-generator.json`

A simpler workflow that generates UGC scripts and scene images without video assembly. Perfect for creators who want to film their own content using the AI-generated script and reference images.

### Features

- AI-generated UGC-style scripts (GPT-4o)
- Optional DALL-E 3 scene images for visual reference
- Multi-language support (FR, EN, ES, DE, IT)
- Filming tips and caption suggestions
- No video rendering service needed

### Required Credentials

| Credential ID | Service | Required For |
|--------------|---------|--------------|
| `openai-credentials` | OpenAI API | Script + Images |

### API Endpoint

```
POST /webhook/generate-tiktok-script
```

### Request Body

```json
{
  "product_name": "InfiniteStories",
  "target_audience": "Parents fatigues",
  "key_benefits": ["Histoires personnalisees", "Enfant devient le heros"],
  "tone": "authentique, chaleureux",
  "duration_seconds": 30,
  "language": "fr",
  "hook_type": "problem-solution",
  "cta": "Lien en bio!",
  "generate_images": true,
  "custom_instructions": "Focus sur le moment du coucher"
}
```

### Additional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `generate_images` | boolean | `true` | Generate DALL-E images for each scene |

### Response

```json
{
  "success": true,
  "script": {
    "hook": "Vous savez ce qui a change nos soirees?",
    "scenes": [
      {
        "id": 1,
        "timestamp": "0:00-0:03",
        "voiceover": "Texte a dire",
        "visual": "Description visuelle",
        "emotion": "curiosite",
        "camera": "selfie"
      }
    ],
    "cta": "Telecharge maintenant!",
    "captions": ["Textes pour overlay"],
    "hashtags": ["parenting", "bedtime"],
    "music_mood": "Soft acoustic",
    "filming_tips": ["Filmer en lumiere naturelle"]
  },
  "generated_images": [
    {
      "scene_id": 1,
      "timestamp": "0:00-0:03",
      "image_url": "https://...",
      "voiceover": "Texte de la scene"
    }
  ],
  "voiceover_text": "Script complet pour TTS externe",
  "tiktok_post": {
    "caption": "Hook + hashtags",
    "captions_overlay": ["Textes"],
    "music_mood": "Soft acoustic"
  },
  "filming_guide": ["Tips de tournage"]
}
```

### Use Cases

1. **DIY Filming**: Use the script and images as storyboard, film yourself
2. **Content Planning**: Generate multiple scripts to choose from
3. **External Video Tools**: Export script to CapCut, InShot, etc.
4. **Team Collaboration**: Share script with video production team

### Estimated Costs

| Service | Cost |
|---------|------|
| OpenAI GPT-4o (script) | ~$0.05 |
| OpenAI DALL-E 3 (images) | ~$0.40 x 5 scenes = $2.00 |
| **Total with images** | **~$2.05** |
| **Total script only** | **~$0.05** |

---

## Quick Start

### 1. Import Workflow

```bash
# Using n8n CLI
n8n import:workflow --input=n8n-workflows/tiktok-ugc-script-generator.json
```

### 2. Configure OpenAI Credentials

In n8n, go to **Settings > Credentials > Add Credential > OpenAI API** and enter your API key.

### 3. Activate & Test

```bash
curl -X POST http://localhost:5678/webhook/generate-tiktok-script \
  -H "Content-Type: application/json" \
  -d '{"language": "fr", "duration_seconds": 30}'
```

---

## Best Practices

### Script Optimization

- **Hook Types**: Test different hook types (problem-solution, question, story) to see what resonates
- **Duration**: 15-30s works best for TikTok ads
- **Language**: Match the language to your target market

### Image Usage

- Use generated images as **storyboard reference**, not final content
- Real UGC performs better than AI-generated visuals on TikTok
- Images help visualize the script for filming

### Cost Control

- Set `generate_images: false` for script-only generation ($0.05/request)
- Generate images only for approved scripts
- Batch multiple briefings to test different angles cheaply
