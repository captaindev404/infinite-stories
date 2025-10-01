# Content Safety Documentation

Comprehensive documentation of the InfiniteStories content safety system, designed to ensure all generated content is appropriate, safe, and enriching for children aged 4-10.

## Overview

The InfiniteStories platform implements a multi-layer content safety system that combines rule-based filtering, AI-powered analysis, and human oversight to guarantee child-appropriate content. This system operates at every stage of content generation, from initial prompts through final delivery.

## Safety Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Content Safety Pipeline                  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Input → Sanitization → Rule Filter → AI Analysis → Output  │
│    ↓          ↓            ↓              ↓           ↓      │
│  Log      Validate      Replace       Analyze      Verify    │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│                      Safety Layers                           │
│                                                               │
│  1. Input Sanitization    (XSS, SQL Injection Prevention)    │
│  2. Rule-Based Filtering  (Word/Phrase Replacement)          │
│  3. AI Content Analysis   (Context Understanding)            │
│  4. Image Prompt Safety   (Visual Appropriateness)           │
│  5. Audio Content Filter  (Voice Tone & Content)             │
│  6. Final Validation      (Comprehensive Check)              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Content Filtering Layers

### Layer 1: Input Sanitization

Prevents malicious input and ensures data safety.

```typescript
// Implementation in content-filter.ts
export class InputSanitizer {
  sanitize(input: string): string {
    // Remove HTML tags
    input = input.replace(/<[^>]*>/g, '');

    // Escape special characters
    input = input.replace(/[<>\"']/g, (char) => {
      const escapeMap = {
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
      };
      return escapeMap[char];
    });

    // Remove potential SQL injection attempts
    input = input.replace(/(\b(DROP|DELETE|INSERT|UPDATE|ALTER)\b)/gi, '');

    // Limit length to prevent buffer overflow
    return input.substring(0, 10000);
  }
}
```

### Layer 2: Rule-Based Content Filtering

Comprehensive word and phrase replacement system.

```typescript
// Rule categories and replacements
const CONTENT_RULES = {
  // Violence and Conflict
  violence: {
    patterns: [
      'fight', 'battle', 'war', 'weapon', 'gun', 'sword', 'knife',
      'hurt', 'harm', 'attack', 'kill', 'dead', 'death', 'blood'
    ],
    replacements: {
      'fight': 'challenge',
      'battle': 'contest',
      'war': 'disagreement',
      'weapon': 'tool',
      'gun': 'gadget',
      'sword': 'wand',
      'knife': 'utensil',
      'hurt': 'help',
      'harm': 'heal',
      'attack': 'approach',
      'kill': 'save',
      'dead': 'sleeping',
      'death': 'rest',
      'blood': 'magic dust'
    }
  },

  // Fear and Darkness
  fear: {
    patterns: [
      'scary', 'frightening', 'terrifying', 'horror', 'nightmare',
      'dark', 'darkness', 'shadow', 'evil', 'monster', 'demon'
    ],
    replacements: {
      'scary': 'mysterious',
      'frightening': 'surprising',
      'terrifying': 'amazing',
      'horror': 'wonder',
      'nightmare': 'dream',
      'dark': 'shaded',
      'darkness': 'nighttime',
      'shadow': 'shade',
      'evil': 'mischievous',
      'monster': 'creature',
      'demon': 'sprite'
    }
  },

  // Isolation and Abandonment
  isolation: {
    patterns: [
      'alone', 'lonely', 'isolated', 'abandoned', 'lost',
      'orphan', 'nobody', 'forgotten', 'neglected'
    ],
    replacements: {
      'alone': 'with friends nearby',
      'lonely': 'independent',
      'isolated': 'in a quiet place',
      'abandoned': 'on an adventure',
      'lost': 'exploring',
      'orphan': 'adventurer',
      'nobody': 'somebody special',
      'forgotten': 'remembered',
      'neglected': 'cherished'
    }
  },

  // Medical and Injury
  medical: {
    patterns: [
      'sick', 'ill', 'disease', 'infection', 'virus',
      'injured', 'broken', 'bleeding', 'pain', 'hospital'
    ],
    replacements: {
      'sick': 'tired',
      'ill': 'resting',
      'disease': 'challenge',
      'infection': 'situation',
      'virus': 'puzzle',
      'injured': 'learning',
      'broken': 'fixable',
      'bleeding': 'glowing',
      'pain': 'sensation',
      'hospital': 'healing center'
    }
  },

  // Family Distress
  family: {
    patterns: [
      'divorce', 'separated', 'absent father', 'absent mother',
      'broken home', 'family problems'
    ],
    replacements: {
      'divorce': 'change',
      'separated': 'in different places',
      'absent father': 'traveling father',
      'absent mother': 'busy mother',
      'broken home': 'unique family',
      'family problems': 'family adventures'
    }
  }
};
```

### Layer 3: AI-Powered Content Analysis

Uses GPT-5 Mini with minimal reasoning effort to understand context and ensure appropriateness with fast processing.

```typescript
interface ContentAnalysis {
  is_appropriate: boolean;
  confidence_score: number;
  concerns: string[];
  suggested_modifications: string[];
  emotional_tone: string;
  age_appropriateness: number;
}

async function analyzeContentWithAI(
  content: string,
  context: string
): Promise<ContentAnalysis> {
  const prompt = `
    Analyze the following children's story content for appropriateness.
    Consider children aged 4-10 as the audience.

    Content: ${content}
    Context: ${context}

    Evaluate for:
    1. Age-appropriate themes and language
    2. Absence of violence, fear, or distressing content
    3. Positive emotional tone
    4. Educational or moral value
    5. Presence of companionship (children not alone)

    Return analysis as JSON with:
    - is_appropriate (boolean)
    - confidence_score (0-1)
    - concerns (array of specific issues)
    - suggested_modifications (array of improvements)
    - emotional_tone (calming/exciting/educational/heartwarming)
    - age_appropriateness (4-10 scale)
  `;

  const response = await openai.createChatCompletion({
    model: 'gpt-5-mini',
    messages: [
      {
        role: 'system',
        content: 'You are a child safety expert specializing in content moderation.'
      },
      {
        role: 'user',
        content: prompt
      }
    ],
    response_format: { type: 'json_object' }
  });

  return JSON.parse(response.choices[0].message.content);
}
```

### Layer 4: Image Prompt Sanitization

Ensures all generated images are child-friendly and appropriate.

```typescript
class ImagePromptSanitizer {
  private readonly REQUIRED_MODIFIERS = [
    'child-friendly',
    'bright and colorful',
    'watercolor style',
    'soft lighting',
    'cheerful atmosphere'
  ];

  private readonly FORBIDDEN_TERMS = [
    'realistic', 'photorealistic', 'dark', 'scary',
    'violent', 'blood', 'weapon', 'nude', 'horror'
  ];

  sanitizePrompt(prompt: string): string {
    // Remove forbidden terms
    this.FORBIDDEN_TERMS.forEach(term => {
      const regex = new RegExp(`\\b${term}\\b`, 'gi');
      prompt = prompt.replace(regex, '');
    });

    // Ensure companionship
    if (this.detectChildInPrompt(prompt) && !this.detectCompanionship(prompt)) {
      prompt += ' accompanied by friendly animal companions';
    }

    // Add required modifiers
    const modifiersToAdd = this.REQUIRED_MODIFIERS.filter(
      modifier => !prompt.toLowerCase().includes(modifier)
    );

    if (modifiersToAdd.length > 0) {
      prompt += ', ' + modifiersToAdd.join(', ');
    }

    // Ensure positive atmosphere
    prompt = this.enforcePositiveImagery(prompt);

    return prompt;
  }

  private detectChildInPrompt(prompt: string): boolean {
    const childTerms = ['child', 'kid', 'boy', 'girl', 'youth', 'young'];
    return childTerms.some(term =>
      prompt.toLowerCase().includes(term)
    );
  }

  private detectCompanionship(prompt: string): boolean {
    const companionTerms = [
      'with', 'friend', 'companion', 'together',
      'group', 'family', 'animal', 'pet'
    ];
    return companionTerms.some(term =>
      prompt.toLowerCase().includes(term)
    );
  }

  private enforcePositiveImagery(prompt: string): string {
    const negativeToPositive = {
      'night': 'starry evening',
      'storm': 'gentle rain',
      'forest': 'enchanted forest',
      'cave': 'crystal cavern',
      'mountain': 'rainbow mountain'
    };

    Object.entries(negativeToPositive).forEach(([negative, positive]) => {
      const regex = new RegExp(`\\b${negative}\\b`, 'gi');
      prompt = prompt.replace(regex, positive);
    });

    return prompt;
  }
}
```

### Layer 5: Audio Content Filtering

Ensures appropriate tone and pacing for bedtime stories.

```typescript
interface AudioSafetyConfig {
  voice: string;
  speed: number;
  pitch: number;
  emotion: string;
  volume_modulation: boolean;
}

class AudioContentFilter {
  getVoiceConfiguration(
    storyType: string,
    targetAge: number
  ): AudioSafetyConfig {
    const baseConfig: AudioSafetyConfig = {
      voice: 'coral', // Warm, nurturing voice
      speed: 0.9, // Slightly slower for clarity
      pitch: 1.0, // Natural pitch
      emotion: 'calm',
      volume_modulation: true
    };

    // Adjust for story type
    if (storyType === 'bedtime') {
      baseConfig.speed = 0.85;
      baseConfig.emotion = 'soothing';
    } else if (storyType === 'adventure') {
      baseConfig.speed = 0.95;
      baseConfig.emotion = 'gentle_excitement';
    }

    // Adjust for age
    if (targetAge < 6) {
      baseConfig.speed *= 0.95; // Even slower for younger children
    }

    return baseConfig;
  }

  filterAudioContent(text: string): string {
    // Remove exclamation marks that might be too exciting
    text = text.replace(/!{2,}/g, '.');

    // Replace intense words with calmer alternatives
    const intensityReplacements = {
      'shouted': 'said cheerfully',
      'screamed': 'called out',
      'yelled': 'announced',
      'whispered eerily': 'whispered gently'
    };

    Object.entries(intensityReplacements).forEach(([intense, calm]) => {
      text = text.replace(new RegExp(intense, 'gi'), calm);
    });

    return text;
  }
}
```

## Companionship Enforcement System

Critical safety feature ensuring children are never depicted as alone or isolated.

```typescript
class CompanionshipEnforcer {
  private readonly COMPANION_TEMPLATES = [
    'with their loyal pet {animal}',
    'accompanied by friendly {creature}',
    'together with their best friend',
    'alongside their magical companion',
    'with their family nearby'
  ];

  private readonly SAFE_COMPANIONS = [
    'dog', 'cat', 'rabbit', 'bird', 'butterfly',
    'fairy', 'dragon', 'unicorn', 'talking animal'
  ];

  enforceCompanionship(content: string, context: any): string {
    const sentences = content.split(/[.!?]+/);

    const processedSentences = sentences.map(sentence => {
      if (this.detectIsolation(sentence)) {
        return this.addCompanion(sentence, context);
      }
      return sentence;
    });

    return processedSentences.join('. ');
  }

  private detectIsolation(sentence: string): boolean {
    const isolationPatterns = [
      /\b(alone|by (him|her|them)self)\b/i,
      /\b(no one|nobody) (was|were) (there|around)\b/i,
      /\b(abandoned|isolated|lost)\b/i
    ];

    return isolationPatterns.some(pattern => pattern.test(sentence));
  }

  private addCompanion(sentence: string, context: any): string {
    const companion = this.selectAppropriateCompanion(context);
    const template = this.COMPANION_TEMPLATES[
      Math.floor(Math.random() * this.COMPANION_TEMPLATES.length)
    ];

    const companionPhrase = template.replace('{animal}', companion)
                                   .replace('{creature}', companion);

    // Insert companion naturally into sentence
    if (sentence.includes('alone')) {
      return sentence.replace('alone', companionPhrase);
    }

    return sentence + ' ' + companionPhrase;
  }

  private selectAppropriateCompanion(context: any): string {
    // Select based on story context
    if (context.setting === 'forest') {
      return 'woodland fairy';
    } else if (context.setting === 'ocean') {
      return 'friendly dolphin';
    } else if (context.setting === 'space') {
      return 'robot friend';
    }

    // Default to random safe companion
    return this.SAFE_COMPANIONS[
      Math.floor(Math.random() * this.SAFE_COMPANIONS.length)
    ];
  }
}
```

## Content Validation Workflow

```typescript
class ContentValidationWorkflow {
  async validateContent(
    content: string,
    contentType: 'story' | 'prompt' | 'audio',
    metadata: any
  ): Promise<ValidationResult> {
    const validationSteps = [
      this.validateLength,
      this.validateLanguage,
      this.validateEmotionalTone,
      this.validateAgeAppropriateness,
      this.validateEducationalValue,
      this.validateSafetyCompliance
    ];

    const results = await Promise.all(
      validationSteps.map(step => step.call(this, content, metadata))
    );

    const allValid = results.every(r => r.valid);
    const issues = results.filter(r => !r.valid).map(r => r.issue);
    const warnings = results.filter(r => r.warning).map(r => r.warning);

    return {
      valid: allValid,
      issues,
      warnings,
      confidence: this.calculateConfidence(results),
      metadata: {
        validated_at: new Date().toISOString(),
        validation_version: '2.0',
        content_hash: this.hashContent(content)
      }
    };
  }

  private async validateLength(
    content: string,
    metadata: any
  ): Promise<StepResult> {
    const wordCount = content.split(/\s+/).length;
    const maxWords = metadata.targetAge < 6 ? 500 : 1000;

    return {
      valid: wordCount <= maxWords,
      issue: wordCount > maxWords ? `Content too long: ${wordCount} words` : null,
      warning: wordCount > maxWords * 0.9 ? 'Content approaching length limit' : null
    };
  }

  private async validateEmotionalTone(
    content: string,
    metadata: any
  ): Promise<StepResult> {
    const toneAnalysis = await this.analyzeTone(content);
    const appropriateTones = ['calm', 'cheerful', 'heartwarming', 'adventurous'];

    return {
      valid: appropriateTones.includes(toneAnalysis.primary_tone),
      issue: !appropriateTones.includes(toneAnalysis.primary_tone)
        ? `Inappropriate tone: ${toneAnalysis.primary_tone}` : null,
      warning: toneAnalysis.intensity > 0.7 ? 'Content may be too intense' : null
    };
  }
}
```

## Monitoring and Reporting

### Safety Metrics Dashboard

```typescript
interface SafetyMetrics {
  total_content_processed: number;
  content_flagged: number;
  content_modified: number;
  content_rejected: number;
  ai_interventions: number;
  rule_interventions: number;
  average_safety_score: number;
  violation_categories: Record<string, number>;
}

class SafetyMonitor {
  async generateDailyReport(): Promise<SafetyMetrics> {
    const query = `
      SELECT
        COUNT(*) as total_processed,
        SUM(CASE WHEN action_taken != 'approved' THEN 1 ELSE 0 END) as flagged,
        SUM(CASE WHEN action_taken = 'modified' THEN 1 ELSE 0 END) as modified,
        SUM(CASE WHEN action_taken = 'rejected' THEN 1 ELSE 0 END) as rejected,
        SUM(CASE WHEN ai_confidence IS NOT NULL THEN 1 ELSE 0 END) as ai_interventions,
        AVG(ai_confidence) as avg_confidence
      FROM content_flags
      WHERE created_at > NOW() - INTERVAL '24 hours'
    `;

    const violations = `
      SELECT
        flag_type,
        COUNT(*) as count
      FROM content_flags
      WHERE created_at > NOW() - INTERVAL '24 hours'
      GROUP BY flag_type
    `;

    // Execute queries and compile report
    return this.compileMetrics(query, violations);
  }

  async alertOnViolation(violation: ContentViolation): Promise<void> {
    if (violation.severity === 'critical') {
      // Immediate alert
      await this.sendImmediateAlert(violation);

      // Log to audit trail
      await this.logToAudit(violation);

      // Potentially disable content generation temporarily
      if (violation.pattern_detected) {
        await this.temporarilyDisableGeneration(violation.user_id);
      }
    }
  }
}
```

### Audit Trail

```sql
-- Comprehensive audit logging for safety events
CREATE TABLE safety_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type TEXT NOT NULL,
    severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    content_type TEXT,
    content_id UUID,
    user_id UUID,
    original_content TEXT,
    filtered_content TEXT,
    action_taken TEXT,
    filter_type TEXT,
    ai_analysis JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Indexes for reporting
    INDEX idx_audit_severity (severity, created_at DESC),
    INDEX idx_audit_user (user_id, created_at DESC),
    INDEX idx_audit_type (event_type, created_at DESC)
);
```

## Testing and Validation

### Safety Test Suite

```typescript
describe('Content Safety System', () => {
  describe('Violence Filtering', () => {
    it('should replace violent terms with safe alternatives', () => {
      const input = 'The hero had to fight the monster';
      const expected = 'The hero had to challenge the creature';

      const filtered = contentFilter.filter(input);
      expect(filtered).toBe(expected);
    });

    it('should detect context and not over-filter', () => {
      const input = 'They had a friendly sword dance';
      const expected = 'They had a friendly wand dance';

      const filtered = contentFilter.filter(input);
      expect(filtered).toBe(expected);
    });
  });

  describe('Companionship Enforcement', () => {
    it('should add companions when child is alone', () => {
      const input = 'The child walked alone through the forest';
      const filtered = companionshipEnforcer.enforce(input);

      expect(filtered).toContain('with');
      expect(filtered).not.toContain('alone');
    });

    it('should not add companions if already present', () => {
      const input = 'The child and their dog explored together';
      const filtered = companionshipEnforcer.enforce(input);

      expect(filtered).toBe(input);
    });
  });

  describe('Image Prompt Safety', () => {
    it('should add safety modifiers to image prompts', () => {
      const input = 'A child in a dark forest';
      const expected = expect.stringContaining('child-friendly');

      const sanitized = imageSanitizer.sanitize(input);
      expect(sanitized).toEqual(expected);
      expect(sanitized).toContain('enchanted forest');
      expect(sanitized).not.toContain('dark');
    });
  });
});
```

### Continuous Safety Validation

```bash
#!/bin/bash
# Automated safety validation script

# Run safety test suite
npm run test:safety

# Analyze recent content
psql $DATABASE_URL -c "
  SELECT
    content_type,
    COUNT(*) as total,
    SUM(CASE WHEN action_taken = 'rejected' THEN 1 ELSE 0 END) as rejected,
    AVG(ai_confidence) as avg_confidence
  FROM content_flags
  WHERE created_at > NOW() - INTERVAL '24 hours'
  GROUP BY content_type
"

# Check for patterns
psql $DATABASE_URL -c "
  SELECT
    flag_type,
    COUNT(*) as occurrences,
    array_agg(DISTINCT user_id) as affected_users
  FROM content_flags
  WHERE created_at > NOW() - INTERVAL '7 days'
  GROUP BY flag_type
  HAVING COUNT(*) > 10
"

# Generate safety report
node scripts/generate-safety-report.js
```

## Compliance and Standards

### COPPA Compliance

```typescript
// Children's Online Privacy Protection Act compliance
class COPPACompliance {
  // No personal information collection from children
  validateNoPersonalInfo(content: string): boolean {
    const personalInfoPatterns = [
      /\b\d{3}-\d{2}-\d{4}\b/, // SSN
      /\b\d{3}-\d{3}-\d{4}\b/, // Phone
      /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, // Email
      /\b\d{1,5}\s\w+\s(Street|St|Avenue|Ave|Road|Rd)\b/i // Address
    ];

    return !personalInfoPatterns.some(pattern => pattern.test(content));
  }
}
```

### Content Rating System

```typescript
interface ContentRating {
  age_group: '4-6' | '6-8' | '8-10';
  safety_score: number; // 0-100
  educational_value: number; // 0-100
  entertainment_value: number; // 0-100
  calmness_factor: number; // 0-100 (for bedtime stories)
  requires_review: boolean;
}

class ContentRatingSystem {
  rateContent(content: string, metadata: any): ContentRating {
    return {
      age_group: this.determineAgeGroup(content, metadata),
      safety_score: this.calculateSafetyScore(content),
      educational_value: this.assessEducationalValue(content),
      entertainment_value: this.assessEntertainmentValue(content),
      calmness_factor: this.calculateCalmnessFactor(content),
      requires_review: this.needsHumanReview(content)
    };
  }
}
```

## Emergency Response

### Critical Safety Incident Protocol

```typescript
class EmergencyResponse {
  async handleCriticalIncident(incident: SafetyIncident): Promise<void> {
    // 1. Immediate content blocking
    await this.blockContent(incident.content_id);

    // 2. User notification
    await this.notifyUser(incident.user_id, {
      message: 'Content temporarily unavailable for safety review',
      alternative: this.getSafeAlternative(incident.content_type)
    });

    // 3. Team escalation
    await this.escalateToTeam({
      severity: 'CRITICAL',
      incident_id: incident.id,
      timestamp: new Date().toISOString(),
      automatic_actions_taken: ['content_blocked', 'user_notified']
    });

    // 4. Pattern analysis
    const pattern = await this.analyzeForPatterns(incident);
    if (pattern.systematic_issue) {
      await this.initiateSystemWideReview(pattern);
    }

    // 5. Documentation
    await this.documentIncident(incident);
  }
}
```

## Best Practices

### Content Generation Guidelines

1. **Always Start Safe**: Begin with the safest possible content and enhance carefully
2. **Layer Safety Checks**: Multiple independent checks are better than one complex check
3. **Fail Safely**: When in doubt, choose the safer alternative
4. **Monitor Continuously**: Real-time monitoring of all generated content
5. **Learn and Adapt**: Use flagged content to improve filters

### Review Process

```typescript
class ContentReviewProcess {
  async reviewFlaggedContent(contentId: string): Promise<ReviewResult> {
    const content = await this.fetchContent(contentId);
    const flags = await this.fetchFlags(contentId);

    const review = {
      reviewer_id: this.getCurrentReviewer(),
      reviewed_at: new Date(),
      original_flags: flags,
      manual_assessment: await this.performManualAssessment(content),
      final_decision: null as 'approve' | 'modify' | 'reject',
      modifications: [] as string[]
    };

    // Decision logic
    if (review.manual_assessment.safe_with_modifications) {
      review.final_decision = 'modify';
      review.modifications = review.manual_assessment.suggested_modifications;
    } else if (review.manual_assessment.completely_safe) {
      review.final_decision = 'approve';
    } else {
      review.final_decision = 'reject';
    }

    await this.saveReview(contentId, review);
    return review;
  }
}
```

---

This comprehensive content safety documentation ensures that all aspects of child safety are addressed in the InfiniteStories platform. The multi-layer approach, combined with continuous monitoring and improvement, provides the highest level of protection for young users.