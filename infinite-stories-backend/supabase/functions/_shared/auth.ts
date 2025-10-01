import { createClient } from 'jsr:@supabase/supabase-js@2';

/**
 * Create Supabase client with service role key for server-side operations
 */
export function createSupabaseServiceClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    }
  );
}

/**
 * Create Supabase client for user operations (with JWT)
 */
export function createSupabaseClient(authToken: string) {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    {
      global: {
        headers: {
          Authorization: authToken
        }
      },
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    }
  );
}

/**
 * Extract and validate JWT token from request headers
 */
export async function validateAuth(req: Request): Promise<{
  userId: string;
  supabase: ReturnType<typeof createSupabaseClient>;
}> {
  const authHeader = req.headers.get('Authorization');

  if (!authHeader) {
    throw new Error('Missing authorization header');
  }

  // Create client with the provided token
  const supabase = createSupabaseClient(authHeader);

  // For local development, skip validation if using the demo token
  const isDemoToken = authHeader.includes('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9');

  // Only allow demo token in development environment
  const isDevelopment = Deno.env.get('ENVIRONMENT') === 'development' ||
                       Deno.env.get('DENO_DEPLOYMENT_ID') === undefined;

  if (isDemoToken) {
    if (!isDevelopment) {
      throw new Error('Demo token not allowed in production environment');
    }
    // Use a fixed dev user ID for local development
    return {
      userId: '00000000-0000-0000-0000-000000000001',
      supabase
    };
  }

  // Validate the token and get user
  const { data: { user }, error } = await supabase.auth.getUser();

  if (error || !user) {
    throw new Error('Invalid or expired token');
  }

  return {
    userId: user.id,
    supabase
  };
}

/**
 * Extract user ID from a validated JWT token without making API calls
 * Use this for performance when you only need the user ID
 */
export function extractUserIdFromJWT(authToken: string): string {
  try {
    // Remove 'Bearer ' prefix if present
    const token = authToken.replace(/^Bearer\s+/i, '');

    // Decode JWT payload (middle part)
    const payload = token.split('.')[1];
    const decoded = JSON.parse(atob(payload));

    return decoded.sub;
  } catch (error) {
    throw new Error('Invalid JWT token format');
  }
}

/**
 * Authentication middleware for Edge Functions
 */
export async function withAuth<T>(
  req: Request,
  handler: (params: {
    userId: string;
    supabase: ReturnType<typeof createSupabaseClient>;
    req: Request;
  }) => Promise<T>
): Promise<T> {
  const { userId, supabase } = await validateAuth(req);

  return handler({
    userId,
    supabase,
    req
  });
}