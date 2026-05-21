# n8n Workflow Specification

## ADDED Requirements

### Requirement: TikTok UGC Script Generation
The workflow SHALL generate UGC-style scripts from a briefing input using OpenAI gpt-5-mini.

The script MUST follow the structure:
- HOOK (0-3 seconds): Attention grabber
- PROBLEM (3-8 seconds): Pain point identification
- DISCOVERY (8-15 seconds): Solution introduction
- BENEFITS (15-25 seconds): Feature highlights
- CTA (25-30 seconds): Call to action

#### Scenario: Script generation from briefing
- **GIVEN** a user provides a briefing with target audience, key message, and tone
- **WHEN** the workflow executes with output_mode containing "script"
- **THEN** the system SHALL generate a structured UGC script with all 5 sections
- **AND** the script SHALL be optimized for TikTok's 9:16 vertical format

#### Scenario: Script includes visual directions
- **GIVEN** a script is generated
- **WHEN** the output is returned
- **THEN** each section SHALL include visual_direction for image/video generation
- **AND** each section SHALL include timing information

---

### Requirement: Audio Voiceover Generation
The workflow SHALL generate audio voiceover from the script using OpenAI gpt-4o-mini-tts.

#### Scenario: Audio generation from script
- **GIVEN** a generated script
- **WHEN** the workflow executes with output_mode "script_audio" or "full_video"
- **THEN** the system SHALL generate MP3 audio for the complete script
- **AND** the voice SHALL match the requested tone (energetic, warm, professional)

#### Scenario: Audio timing matches script sections
- **GIVEN** audio is generated
- **WHEN** the output is returned
- **THEN** the audio duration SHALL approximately match the script timing (25-30 seconds)

---

### Requirement: Scene Image Generation
The workflow SHALL generate scene images from visual directions using Replicate flux-1.1-pro.

#### Scenario: Image generation for each section
- **GIVEN** a script with 5 sections and visual_directions
- **WHEN** the workflow executes with output_mode "script_images" or "full_video"
- **THEN** the system SHALL generate one image per section (5 images total)
- **AND** images SHALL be 1024x1792 (9:16 aspect ratio)

#### Scenario: Image style consistency
- **GIVEN** images are generated for a script
- **WHEN** multiple images are created
- **THEN** all images SHALL maintain consistent style based on the briefing tone

---

### Requirement: Video Assembly
The workflow SHALL assemble final video from audio and images using Replicate video models.

#### Scenario: Full video generation
- **GIVEN** generated audio and images
- **WHEN** the workflow executes with output_mode "full_video"
- **THEN** the system SHALL generate a 9:16 vertical video
- **AND** video duration SHALL be 25-30 seconds
- **AND** images SHALL be animated with transitions

#### Scenario: Video uses image-to-video model
- **GIVEN** the video generation step
- **WHEN** Replicate is called
- **THEN** the system SHALL use minimax/video-01 or kling-v1.6-pro model
- **AND** the system SHALL poll for completion with exponential backoff

---

### Requirement: Conditional Output Modes
The workflow SHALL support multiple output modes to control generation scope.

#### Scenario: Script only mode
- **GIVEN** output_mode is "script_only"
- **WHEN** the workflow completes
- **THEN** only the script JSON SHALL be returned
- **AND** no audio, images, or video SHALL be generated

#### Scenario: Script with audio mode
- **GIVEN** output_mode is "script_audio"
- **WHEN** the workflow completes
- **THEN** script and audio_url SHALL be returned
- **AND** no images or video SHALL be generated

#### Scenario: Script with images mode
- **GIVEN** output_mode is "script_images"
- **WHEN** the workflow completes
- **THEN** script and image_urls array SHALL be returned
- **AND** no video SHALL be generated

#### Scenario: Full video mode
- **GIVEN** output_mode is "full_video"
- **WHEN** the workflow completes
- **THEN** script, audio_url, image_urls, and video_url SHALL be returned

---

### Requirement: Form-Based Input Interface
The workflow SHALL provide a form-based interface for briefing input.

#### Scenario: Form trigger with required fields
- **GIVEN** a user accesses the workflow
- **WHEN** the form is displayed
- **THEN** the form SHALL include:
  - target_audience (required, text)
  - key_message (required, text)
  - tone (required, dropdown: energetic/warm/professional)
  - output_mode (required, dropdown)
  - additional_context (optional, text)

#### Scenario: Form validation
- **GIVEN** a user submits the form
- **WHEN** required fields are missing
- **THEN** the form SHALL display validation errors
- **AND** the workflow SHALL NOT execute
