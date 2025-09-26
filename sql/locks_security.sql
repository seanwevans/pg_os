\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
DROP ROLE IF EXISTS pg_os_limited;
CREATE ROLE pg_os_limited LOGIN;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- Prepare data owned by the extension owner
INSERT INTO users (username)
VALUES ('security_test_user')
RETURNING id AS process_owner \gset

INSERT INTO processes (name, state, priority, owner_user_id, duration)
VALUES ('security_test_process', 'ready', 1, :'process_owner', 1)
RETURNING id AS process_id \gset

INSERT INTO threads (process_id, name, state, priority)
VALUES (:'process_id', 'security_thread', 'ready', 1)
RETURNING id AS thread_id \gset

SET ROLE pg_os_limited;

-- Direct table access should fail for the limited role
\set ON_ERROR_STOP off
INSERT INTO mutexes (name) VALUES ('direct_mutex_attempt');
\set ON_ERROR_STOP on

-- Security-definer helpers should still succeed
SELECT create_mutex('limited_mutex') AS create_mutex_result;
SELECT lock_mutex(:'thread_id', 'limited_mutex') AS lock_mutex_result;
SELECT unlock_mutex(:'thread_id', 'limited_mutex') AS unlock_mutex_result;
SELECT create_semaphore('limited_sem', 1, 1) AS create_semaphore_result;
SELECT acquire_semaphore(:'process_id', 'limited_sem') AS acquire_semaphore_result;
SELECT release_semaphore(:'process_id', 'limited_sem') AS release_semaphore_result;

RESET ROLE;

-- Verify helper effects as the extension owner
SELECT name, locked_by_thread FROM mutexes WHERE name = 'limited_mutex';
SELECT name, count FROM semaphores WHERE name = 'limited_sem';

DROP ROLE pg_os_limited;
