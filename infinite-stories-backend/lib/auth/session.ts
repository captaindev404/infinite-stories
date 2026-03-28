import { auth } from "./auth";
import { headers } from "next/headers";
import { prisma } from "@/lib/prisma/client";
import { AuthenticationError } from "@/lib/utils/api-response";

/**
 * Get the current session from Better Auth
 * Supports both cookie-based (web) and Bearer token (mobile) authentication
 */
export async function getSession() {
  const headersList = await headers();

  try {
    const session = await auth.api.getSession({
      headers: headersList,
    });
    return session;
  } catch (error) {
    console.error("Error getting session:", error);
    return null;
  }
}

/**
 * Get the authenticated user from the session
 * Returns null if the user is not authenticated
 * Use this for route handlers that need auth
 */
export async function requireAuth() {
  const session = await getSession();

  if (!session?.user) {
    return null;
  }

  return session.user;
}

/**
 * Check if the current request is authenticated
 * Returns the user if authenticated, throws error if not
 * Use this when you want to throw on unauthenticated requests
 */
export async function requireAuthOrThrow() {
  const user = await requireAuth();

  if (!user) {
    throw new AuthenticationError();
  }

  return user;
}

/**
 * Get the authenticated user with full database information
 */
export async function getOrCreateUser() {
  const sessionUser = await requireAuth();

  if (!sessionUser) {
    throw new AuthenticationError();
  }

  // Get user from database
  const user = await prisma.user.findUnique({
    where: { id: sessionUser.id },
  });

  if (!user) {
    throw new Error("User not found in database");
  }

  return user;
}

/**
 * Check if a resource belongs to the authenticated user
 */
export async function verifyResourceOwnership(resourceUserId: string) {
  const user = await requireAuth();

  if (!user) {
    throw new AuthenticationError();
  }

  if (user.id !== resourceUserId) {
    throw new Error("Forbidden: You do not have access to this resource");
  }

  return user;
}

/**
 * Get user ID from session (shorthand)
 */
export async function getUserId(): Promise<string> {
  const user = await requireAuth();

  if (!user) {
    throw new AuthenticationError();
  }

  return user.id;
}

export interface SessionUser {
  id: string;
  email: string;
  name: string | null;
  image: string | null;
  emailVerified: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ValidatedSession {
  user: SessionUser;
  session: {
    id: string;
    token: string;
    expiresAt: Date;
  };
}

/**
 * Validate a session token and return the associated user
 * This is used for Bearer token authentication from mobile apps
 */
export async function validateSessionToken(
  token: string
): Promise<ValidatedSession | null> {
  try {
    // Find session by token
    const session = await prisma.session.findFirst({
      where: {
        token: token,
        expiresAt: {
          gt: new Date(), // Session must not be expired
        },
      },
      include: {
        user: true,
      },
    });

    if (!session || !session.user) {
      return null;
    }

    // Return validated session with user
    return {
      user: {
        id: session.user.id,
        email: session.user.email,
        name: session.user.name,
        image: session.user.image,
        emailVerified: session.user.emailVerified,
        createdAt: session.user.createdAt,
        updatedAt: session.user.updatedAt,
      },
      session: {
        id: session.id,
        token: session.token,
        expiresAt: session.expiresAt,
      },
    };
  } catch (error) {
    console.error("Error validating session token:", error);
    return null;
  }
}
