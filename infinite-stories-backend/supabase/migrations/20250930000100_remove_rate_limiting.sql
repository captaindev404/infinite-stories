-- Remove rate limiting functionality

-- Drop RLS policies on rate_limits table
DROP POLICY IF EXISTS "Users can view their own rate limits" ON rate_limits;
DROP POLICY IF EXISTS "System can manage rate limits" ON rate_limits;

-- Drop functions
DROP FUNCTION IF EXISTS check_rate_limit(UUID, TEXT, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS increment_rate_limit(UUID, TEXT, INTEGER);

-- Drop indexes
DROP INDEX IF EXISTS idx_rate_limits_user_function;

-- Drop table
DROP TABLE IF EXISTS rate_limits;
