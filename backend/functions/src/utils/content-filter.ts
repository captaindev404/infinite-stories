/**
 * Content filtering utilities for child-safe avatar generation
 * Based on AIService.swift enhanced sanitization (lines 812-948)
 */

export interface ContentFilterResult {
  filtered: string;
  wasModified: boolean;
  modifications: string[];
}

/**
 * Enhanced basic sanitization for avatar prompts
 * Ensures child-friendly content and prevents isolation
 */
export function enhancedBasicSanitization(prompt: string): ContentFilterResult {
  const modifications: string[] = [];

  // First, remove all non-ASCII characters to avoid foreign language issues
  const asciiOnly = prompt.replace(/[^\x00-\x7F]/g, '');

  if (asciiOnly !== prompt) {
    modifications.push('Removed non-ASCII characters');
  }

  // Then apply all safety transformations
  const result = basicPromptSanitization(asciiOnly);

  return {
    filtered: result.filtered,
    wasModified: result.wasModified || asciiOnly !== prompt,
    modifications: [...modifications, ...result.modifications]
  };
}

/**
 * Basic prompt sanitization with comprehensive safety filters
 */
function basicPromptSanitization(prompt: string): ContentFilterResult {
  let sanitized = prompt;
  const modifications: string[] = [];

  // Critical phrase replacements for child safety - order matters (longer phrases first)
  const phraseReplacements: [string, string][] = [
    // Isolation phrases
    ['standing alone', 'standing with friends'],
    ['sitting alone', 'sitting with companions'],
    ['walking alone', 'walking with friends'],
    ['all alone', 'with magical friends'],
    ['by himself', 'with his friends'],
    ['by herself', 'with her friends'],
    ['by themselves', 'with their companions'],

    // Dark/scary phrases
    ['dark forest', 'bright enchanted garden'],
    ['dark woods', 'sunny magical meadow'],
    ['scary forest', 'magical garden'],
    ['haunted house', 'magical castle'],
    ['abandoned house', 'cozy cottage'],

    // Violence phrases
    ['fighting with', 'playing with'],
    ['in battle', 'on an adventure']
  ];

  // Apply phrase replacements
  for (const [problematic, safe] of phraseReplacements) {
    const regex = new RegExp(problematic, 'gi');
    const newSanitized = sanitized.replace(regex, safe);
    if (newSanitized !== sanitized) {
      modifications.push(`Replaced "${problematic}" with "${safe}"`);
      sanitized = newSanitized;
    }
  }

  // Word replacements - use word boundaries for accuracy
  const wordReplacements: [string, string][] = [
    // Isolation words
    ['\\balone\\b', 'with friends'],
    ['\\blonely\\b', 'happy with companions'],
    ['\\bisolated\\b', 'surrounded by friendly creatures'],
    ['\\babandoned\\b', 'in a cozy magical place'],
    ['\\bsolitary\\b', 'with cheerful friends'],
    ['\\bsolo\\b', 'with companions'],

    // Dark/scary words
    ['\\bdark\\b', 'bright'],
    ['\\bscary\\b', 'wonderful'],
    ['\\bfrightening\\b', 'magical'],
    ['\\bterrifying\\b', 'amazing'],
    ['\\bspooky\\b', 'enchanting'],
    ['\\bhaunted\\b', 'magical'],
    ['\\bmysterious\\b', 'delightful'],
    ['\\bshadowy\\b', 'glowing'],
    ['\\bgloomy\\b', 'bright'],
    ['\\beerie\\b', 'cheerful'],
    ['\\bcreepy\\b', 'friendly'],

    // Violence words
    ['\\bfighting\\b', 'playing'],
    ['\\bbattle\\b', 'adventure'],
    ['\\bweapon\\b', 'magical wand'],
    ['\\bsword\\b', 'toy wand'],
    ['\\bswords\\b', 'toy wands'],
    ['\\battacking\\b', 'playing with'],

    // Negative emotion words
    ['\\bsad\\b', 'happy'],
    ['\\bcrying\\b', 'smiling'],
    ['\\btears\\b', 'sparkles'],
    ['\\bupset\\b', 'curious'],
    ['\\bangry\\b', 'determined'],
    ['\\bscared\\b', 'excited'],
    ['\\bafraid\\b', 'brave'],
    ['\\bworried\\b', 'thoughtful'],
    ['\\bfrightened\\b', 'amazed']
  ];

  // Apply word replacements using regex
  for (const [problematic, safe] of wordReplacements) {
    try {
      const regex = new RegExp(problematic, 'gi');
      const newSanitized = sanitized.replace(regex, safe);
      if (newSanitized !== sanitized) {
        const word = problematic.replace(/\\b/g, '');
        modifications.push(`Replaced word "${word}" with "${safe}"`);
        sanitized = newSanitized;
      }
    } catch (error) {
      // Fallback to simple replacement if regex fails
      const simplePattern = problematic.replace(/\\b/g, '');
      const regex = new RegExp(simplePattern, 'gi');
      const newSanitized = sanitized.replace(regex, safe);
      if (newSanitized !== sanitized) {
        modifications.push(`Replaced "${simplePattern}" with "${safe}"`);
        sanitized = newSanitized;
      }
    }
  }

  // Ensure the character is not alone
  const hasCompanions = sanitized.toLowerCase().includes('friends') ||
    sanitized.toLowerCase().includes('companions') ||
    sanitized.toLowerCase().includes('family') ||
    sanitized.toLowerCase().includes('creatures');

  if (!hasCompanions) {
    // Add companions to the scene
    sanitized = sanitized.replace(/\.$/, '');
    sanitized += ' surrounded by friendly magical creatures and companions.';
    modifications.push('Added companions to prevent isolation');
  }

  // Add brightness if not present
  const hasBrightness = sanitized.toLowerCase().includes('bright') ||
    sanitized.toLowerCase().includes('colorful') ||
    sanitized.toLowerCase().includes('sunny') ||
    sanitized.toLowerCase().includes('cheerful');

  if (!hasBrightness) {
    sanitized += ' The scene is bright, colorful, cheerful, and child-friendly with warm sunlight and a magical atmosphere.';
    modifications.push('Added brightness and positive atmosphere');
  }

  return {
    filtered: sanitized,
    wasModified: sanitized !== prompt,
    modifications
  };
}

/**
 * Build comprehensive avatar prompt for DALL-E generation
 */
export function buildAvatarPrompt(hero: any, userPrompt: string): string {
  // Base style and safety requirements
  const baseStyle = `Create a beautiful children's book character illustration in a warm, whimsical style.
Use soft colors, gentle lighting, and a magical atmosphere.
The art style should be similar to modern children's picture books with watercolor or soft digital painting techniques.
Ensure the image is appropriate for children aged 4-10.
Focus on creating a sense of wonder and joy.`;

  // Hero characteristics
  const heroDescription = `
Character name: ${hero.name}
Primary trait: ${hero.primary_trait || hero.primaryTrait} (should be reflected in expression and posture)
Secondary trait: ${hero.secondary_trait || hero.secondaryTrait} (subtle personality indicator)
Appearance: ${hero.appearance || 'friendly and approachable'}
Special ability: ${hero.special_ability || hero.specialAbility || 'kindness and courage'}`;

  // Safety and companionship requirements
  const safetyRequirements = `
CRITICAL SAFETY REQUIREMENTS:
- The character MUST be shown with friendly companions (magical creatures, animal friends, or other characters)
- NO isolation or loneliness - always include friendly elements in the scene
- Bright, colorful, cheerful atmosphere with warm lighting
- Peaceful, happy expression showing confidence and kindness
- Safe, magical environment (enchanted garden, cozy cottage, magical library, etc.)
- All elements must be child-friendly and positive`;

  // Combine all elements
  return `${baseStyle}

${heroDescription}

User requirements: ${userPrompt}

${safetyRequirements}

The final image should be a delightful character portrait that children would love to see as their story hero, surrounded by a magical, friendly world.`;
}