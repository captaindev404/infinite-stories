/**
 * Clamp pagination parameters to safe defaults.
 * - limit: 1–100, default 50
 * - offset: >= 0, default 0
 */
export function clampPagination(rawLimit?: string | null, rawOffset?: string | null) {
  const limit = Math.min(Math.max(parseInt(rawLimit || '', 10) || 50, 1), 100);
  const offset = Math.max(parseInt(rawOffset || '', 10) || 0, 0);
  return { limit, offset };
}
