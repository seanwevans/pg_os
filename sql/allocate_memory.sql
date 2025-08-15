-- tests for memory allocation
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;

-- setup users, roles, permissions, and process
SELECT create_user('alice') AS alice_id \gset
SELECT create_user('bob')   AS bob_id   \gset
SELECT create_role('mem_role') AS role_id \gset
SELECT assign_role_to_user(:bob_id, :role_id);
SELECT grant_permission_to_role(:role_id, 'memory', 'allocate');

INSERT INTO memory_segments (size) VALUES (1024);
INSERT INTO processes (name, state, owner_user_id) VALUES ('proc1', 'new', :bob_id);

\set ECHO queries
\set VERBOSITY terse

-- successful allocation
SELECT allocate_memory(:bob_id, 1, 512);
SELECT process_id, segment_id FROM process_memory;

\set ON_ERROR_STOP off
-- allocation without permission should fail
SELECT allocate_memory(:alice_id, 1, 512);
\set ON_ERROR_STOP on
