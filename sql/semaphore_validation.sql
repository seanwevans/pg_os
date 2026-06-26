-- create_semaphore must reject parameters that would violate the
-- "0 <= count <= max_count, max_count >= 1" invariant.
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- a valid semaphore is accepted
SELECT create_semaphore('ok', 1, 2);
SELECT name, count, max_count FROM semaphores WHERE name = 'ok';

\set ON_ERROR_STOP off
-- initial count greater than the maximum is rejected
SELECT create_semaphore('too_many', 5, 1);
-- negative initial count is rejected
SELECT create_semaphore('negative', -1, 2);
-- a maximum below 1 is rejected
SELECT create_semaphore('no_max', 0, 0);
\set ON_ERROR_STOP on

-- none of the invalid semaphores were created
SELECT count(*) AS semaphore_count FROM semaphores;
