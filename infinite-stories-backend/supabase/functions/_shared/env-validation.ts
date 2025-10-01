/**
 * Environment Variable Validation
 *
 * Ensures all required environment variables are present at function startup.
 * This helps catch configuration issues early and provides clear error messages.
 */

export interface RequiredEnvVars {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  OPENAI_API_KEY: string;
}

export interface OptionalEnvVars {
  ENVIRONMENT?: string;
  DENO_DEPLOYMENT_ID?: string;
  SB_REGION?: string;
  SB_EXECUTION_ID?: string;
}

/**
 * Validate that all required environment variables are present
 * @throws Error if any required variables are missing
 */
export function validateEnvironmentVariables(): void {
  const requiredVars: (keyof RequiredEnvVars)[] = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
    'OPENAI_API_KEY'
  ];

  const missingVars: string[] = [];

  for (const varName of requiredVars) {
    const value = Deno.env.get(varName);
    if (!value || value.trim() === '') {
      missingVars.push(varName);
    }
  }

  if (missingVars.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missingVars.join(', ')}. ` +
      `Please ensure all required variables are set in your environment.`
    );
  }

  // Log environment info (without sensitive values)
  const environment = Deno.env.get('ENVIRONMENT') || 'production';
  const deploymentId = Deno.env.get('DENO_DEPLOYMENT_ID');
  const region = Deno.env.get('SB_REGION');

  console.log('Environment validated successfully', {
    environment,
    deploymentId: deploymentId ? deploymentId.substring(0, 8) + '...' : 'local',
    region: region || 'unknown',
    supabaseUrl: Deno.env.get('SUPABASE_URL')?.replace(/https?:\/\/([^\.]+)\..*/, '$1.supabase.co')
  });
}

/**
 * Get environment variable with fallback
 */
export function getEnvVar(name: string, fallback?: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value === '') {
    if (fallback !== undefined) {
      return fallback;
    }
    throw new Error(`Environment variable ${name} is not set`);
  }
  return value;
}

/**
 * Check if running in production
 */
export function isProduction(): boolean {
  const environment = Deno.env.get('ENVIRONMENT');
  const deploymentId = Deno.env.get('DENO_DEPLOYMENT_ID');

  // Consider it production if:
  // 1. ENVIRONMENT is explicitly set to 'production'
  // 2. Or DENO_DEPLOYMENT_ID is set (running on Deno Deploy)
  return environment === 'production' || deploymentId !== undefined;
}

/**
 * Check if running in development
 */
export function isDevelopment(): boolean {
  return !isProduction();
}