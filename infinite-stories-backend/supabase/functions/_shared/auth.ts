import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

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