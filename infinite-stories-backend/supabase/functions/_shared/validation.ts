import { APIError, ErrorCode, createValidationError } from './errors.ts';

/**
 * Validation schema types
 */
export interface ValidationSchema {
  [key: string]: ValidationRule;
}

export interface ValidationRule {
  type: 'string' | 'number' | 'boolean' | 'object' | 'array' | 'uuid';
  required?: boolean;
  min?: number;
  max?: number;
  pattern?: RegExp;
  enum?: string[];
  schema?: ValidationSchema; // For nested objects
  items?: ValidationRule; // For arrays
}

/**
 * Hero validation schema (matches iOS Hero model)
 */
export const HeroSchema: ValidationSchema = {
  name: {
    type: 'string',
    required: true,
    min: 1,
    max: 50
  },
  primary_trait: {
    type: 'string',
    required: true,
    enum: ['brave', 'kind', 'clever', 'funny', 'creative', 'helpful', 'curious']
  },
  secondary_trait: {
    type: 'string',
    required: true,
    enum: ['adventurous', 'gentle', 'wise', 'playful', 'artistic', 'caring', 'determined']
  },
  appearance: {
    type: 'string',
    required: false,
    max: 500
  },
  special_ability: {
    type: 'string',
    required: false,
    max: 200
  }
};

/**
 * Story generation request schema
 */
export const StoryGenerationSchema: ValidationSchema = {
  hero_id: {
    type: 'uuid',
    required: true
  },
  event: {
    type: 'object',
    required: true,
    schema: {
      type: {
        type: 'string',
        required: true,
        enum: ['built_in', 'custom']
      },
      data: {
        type: 'object',
        required: true
      }
    }
  },
  target_duration: {
    type: 'number',
    required: true,
    min: 60,
    max: 600
  },
  language: {
    type: 'string',
    required: true,
    enum: ['en', 'es', 'fr', 'de', 'it']
  }
};

/**
 * Custom event schema
 */
export const CustomEventSchema: ValidationSchema = {
  title: {
    type: 'string',
    required: true,
    min: 1,
    max: 100
  },
  description: {
    type: 'string',
    required: false,
    max: 500
  },
  prompt_seed: {
    type: 'string',
    required: true,
    min: 10,
    max: 1000
  },
  category: {
    type: 'string',
    required: false,
    enum: ['adventure', 'friendship', 'learning', 'fantasy', 'family', 'nature']
  },
  age_range: {
    type: 'string',
    required: false,
    enum: ['3-5', '5-7', '7-10', '10-12']
  },
  tone: {
    type: 'string',
    required: false,
    enum: ['playful', 'gentle', 'exciting', 'calming', 'educational']
  },
  keywords: {
    type: 'array',
    required: false,
    items: {
      type: 'string',
      max: 50
    }
  }
};

/**
 * Audio synthesis request schema
 */
export const AudioSynthesisSchema: ValidationSchema = {
  story_id: {
    type: 'uuid',
    required: true
  },
  text: {
    type: 'string',
    required: true,
    min: 1,
    max: 50000 // Approximately 10,000 words
  },
  voice: {
    type: 'string',
    required: true,
    enum: ['coral', 'nova', 'fable', 'alloy', 'echo', 'onyx', 'shimmer']
  },
  language: {
    type: 'string',
    required: true,
    enum: ['en', 'es', 'fr', 'de', 'it']
  }
};

/**
 * Avatar generation request schema
 */
export const AvatarGenerationSchema: ValidationSchema = {
  hero_id: {
    type: 'uuid',
    required: true
  },
  prompt: {
    type: 'string',
    required: true,
    min: 10,
    max: 1000
  },
  size: {
    type: 'string',
    required: false,
    enum: ['1024x1024', '1792x1024', '1024x1792']
  },
  quality: {
    type: 'string',
    required: false,
    enum: ['low', 'medium', 'high']
  },
  previous_generation_id: {
    type: 'string',
    required: false
  }
};

/**
 * Scene illustration request schema
 */
export const SceneIllustrationSchema: ValidationSchema = {
  story_id: {
    type: 'uuid',
    required: true
  },
  scenes: {
    type: 'array',
    required: true,
    min: 1,
    max: 20, // Reasonable limit for batch processing
    items: {
      type: 'object',
      schema: {
        scene_number: {
          type: 'number',
          required: true,
          min: 1
        },
        text_segment: {
          type: 'string',
          required: true,
          min: 1,
          max: 1000
        },
        illustration_prompt: {
          type: 'string',
          required: true,
          min: 10,
          max: 1000
        },
        timestamp_seconds: {
          type: 'number',
          required: true,
          min: 0
        },
        emotion: {
          type: 'string',
          required: false,
          enum: ['joyful', 'peaceful', 'exciting', 'mysterious', 'heartwarming', 'adventurous', 'contemplative']
        },
        importance: {
          type: 'string',
          required: false,
          enum: ['key', 'major', 'minor']
        }
      }
    }
  },
  hero_id: {
    type: 'uuid',
    required: true
  }
};

/**
 * Validator class
 */
export class Validator {
  /**
   * Validate a value against a rule
   */
  private validateValue(value: any, rule: ValidationRule, fieldName: string): void {
    // Required field check
    if (rule.required && (value === undefined || value === null)) {
      throw createValidationError(`Field '${fieldName}' is required`);
    }

    // Skip validation for optional undefined values
    if (!rule.required && (value === undefined || value === null)) {
      return;
    }

    // Type validation
    switch (rule.type) {
      case 'string':
        if (typeof value !== 'string') {
          throw createValidationError(`Field '${fieldName}' must be a string`);
        }
        this.validateString(value, rule, fieldName);
        break;

      case 'number':
        if (typeof value !== 'number' || isNaN(value)) {
          throw createValidationError(`Field '${fieldName}' must be a number`);
        }
        this.validateNumber(value, rule, fieldName);
        break;

      case 'boolean':
        if (typeof value !== 'boolean') {
          throw createValidationError(`Field '${fieldName}' must be a boolean`);
        }
        break;

      case 'uuid':
        if (typeof value !== 'string') {
          throw createValidationError(`Field '${fieldName}' must be a string`);
        }
        this.validateUUID(value, fieldName);
        break;

      case 'object':
        if (typeof value !== 'object' || Array.isArray(value) || value === null) {
          throw createValidationError(`Field '${fieldName}' must be an object`);
        }
        if (rule.schema) {
          this.validateObject(value, rule.schema, fieldName);
        }
        break;

      case 'array':
        if (!Array.isArray(value)) {
          throw createValidationError(`Field '${fieldName}' must be an array`);
        }
        this.validateArray(value, rule, fieldName);
        break;

      default:
        throw new Error(`Unknown validation type: ${rule.type}`);
    }
  }

  /**
   * Validate string value
   */
  private validateString(value: string, rule: ValidationRule, fieldName: string): void {
    if (rule.min !== undefined && value.length < rule.min) {
      throw createValidationError(`Field '${fieldName}' must be at least ${rule.min} characters`);
    }

    if (rule.max !== undefined && value.length > rule.max) {
      throw createValidationError(`Field '${fieldName}' must be at most ${rule.max} characters`);
    }

    if (rule.pattern && !rule.pattern.test(value)) {
      throw createValidationError(`Field '${fieldName}' format is invalid`);
    }

    if (rule.enum && !rule.enum.includes(value)) {
      throw createValidationError(
        `Field '${fieldName}' must be one of: ${rule.enum.join(', ')}`
      );
    }
  }

  /**
   * Validate number value
   */
  private validateNumber(value: number, rule: ValidationRule, fieldName: string): void {
    if (rule.min !== undefined && value < rule.min) {
      throw createValidationError(`Field '${fieldName}' must be at least ${rule.min}`);
    }

    if (rule.max !== undefined && value > rule.max) {
      throw createValidationError(`Field '${fieldName}' must be at most ${rule.max}`);
    }
  }

  /**
   * Validate UUID format
   */
  private validateUUID(value: string, fieldName: string): void {
    const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidPattern.test(value)) {
      throw createValidationError(`Field '${fieldName}' must be a valid UUID`);
    }
  }

  /**
   * Validate object against schema
   */
  private validateObject(value: Record<string, any>, schema: ValidationSchema, fieldName: string): void {
    // Check for unknown fields
    const allowedFields = Object.keys(schema);
    const providedFields = Object.keys(value);

    for (const field of providedFields) {
      if (!allowedFields.includes(field)) {
        throw createValidationError(`Unknown field '${fieldName}.${field}'`);
      }
    }

    // Validate each field in schema
    for (const [field, rule] of Object.entries(schema)) {
      this.validateValue(value[field], rule, `${fieldName}.${field}`);
    }
  }

  /**
   * Validate array items
   */
  private validateArray(value: any[], rule: ValidationRule, fieldName: string): void {
    if (rule.min !== undefined && value.length < rule.min) {
      throw createValidationError(`Field '${fieldName}' must have at least ${rule.min} items`);
    }

    if (rule.max !== undefined && value.length > rule.max) {
      throw createValidationError(`Field '${fieldName}' must have at most ${rule.max} items`);
    }

    // Validate each array item
    if (rule.items) {
      value.forEach((item, index) => {
        this.validateValue(item, rule.items!, `${fieldName}[${index}]`);
      });
    }
  }

  /**
   * Validate data against schema
   */
  validate(data: any, schema: ValidationSchema): void {
    if (typeof data !== 'object' || Array.isArray(data) || data === null) {
      throw createValidationError('Request body must be an object');
    }

    this.validateObject(data, schema, 'body');
  }
}

/**
 * Singleton validator instance
 */
export const validator = new Validator();

/**
 * Validation middleware
 */
export function validateRequest<T>(
  data: any,
  schema: ValidationSchema
): T {
  validator.validate(data, schema);
  return data as T;
}

/**
 * Parse and validate JSON request body
 */
export async function parseAndValidateJSON<T>(
  req: Request,
  schema: ValidationSchema
): Promise<T> {
  let body: any;

  try {
    body = await req.json();
  } catch (error) {
    throw createValidationError('Invalid JSON in request body');
  }

  return validateRequest<T>(body, schema);
}