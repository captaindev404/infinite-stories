import { type ZodSchema, ZodError } from 'zod';
import { requireAuth } from '@/lib/auth/session';
import { errorResponse, handleApiError } from '@/lib/utils/api-response';

/** The user object returned by requireAuth() (non-null branch). */
export type AuthUser = NonNullable<Awaited<ReturnType<typeof requireAuth>>>;

/**
 * Format Zod validation errors into readable messages.
 */
function formatZodErrors(error: ZodError): string {
  return error.issues
    .map((issue) => {
      const path = issue.path.length > 0 ? issue.path.join('.') : 'body';
      return `${path}: ${issue.message}`;
    })
    .join('; ');
}

/**
 * Wrapper for POST endpoints that require authentication AND body validation.
 *
 * 1. Authenticates the request via requireAuth()
 * 2. Parses + validates the JSON body with a Zod schema
 * 3. Calls the handler with the authenticated user and validated body
 * 4. Catches all errors via handleApiError
 */
export async function withAuthAndValidation<T>(
  request: Request,
  schema: ZodSchema<T>,
  _operation: string, // rate limit operation name (reserved for future use)
  handler: (user: AuthUser, body: T) => Promise<Response>,
): Promise<Response> {
  try {
    // 1. Authenticate
    const user = await requireAuth();
    if (!user) {
      return errorResponse('Unauthorized', 'Authentication required', 401);
    }

    // 2. Parse and validate body
    let rawBody: unknown;
    try {
      rawBody = await request.json();
    } catch {
      return errorResponse('ValidationError', 'Invalid or missing JSON body', 400);
    }

    const parseResult = schema.safeParse(rawBody);
    if (!parseResult.success) {
      return errorResponse(
        'ValidationError',
        formatZodErrors(parseResult.error),
        400,
      );
    }

    // 3. Call handler
    return await handler(user, parseResult.data);
  } catch (error) {
    return handleApiError(error);
  }
}

/**
 * Wrapper for endpoints that require authentication but no body validation.
 *
 * 1. Authenticates the request via requireAuth()
 * 2. Calls the handler with the authenticated user
 * 3. Catches all errors via handleApiError
 */
export async function withAuth(
  _request: Request,
  handler: (user: AuthUser) => Promise<Response>,
): Promise<Response> {
  try {
    // 1. Authenticate
    const user = await requireAuth();
    if (!user) {
      return errorResponse('Unauthorized', 'Authentication required', 401);
    }

    // 2. Call handler
    return await handler(user);
  } catch (error) {
    return handleApiError(error);
  }
}
