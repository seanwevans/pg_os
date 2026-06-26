-- tests for free_memory (single-segment release)
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup: user with memory permission, a process, and one free segment
SELECT create_user('mem_user') AS uid \gset
SELECT create_role('mem_role') AS rid \gset
SELECT assign_role_to_user(:uid, :rid);
SELECT grant_permission_to_role(:rid, 'memory', 'allocate');
INSERT INTO processes (name, state, owner_user_id)
VALUES ('mem_proc', 'running', :uid)
RETURNING id AS pid \gset
INSERT INTO memory_segments (size) VALUES (2048);

-- allocate, then confirm the segment is owned by the process
SELECT allocate_memory(:uid, :pid, 1024);
SELECT allocated, allocated_to FROM memory_segments ORDER BY id;
SELECT process_id, segment_id FROM process_memory;

-- free it and confirm the segment is released
SELECT free_memory(:uid, :pid, 1);
SELECT allocated, allocated_to FROM memory_segments ORDER BY id;
SELECT count(*) AS process_memory_rows FROM process_memory;

-- freeing a segment that is not allocated to the process fails
\set ON_ERROR_STOP off
SELECT free_memory(:uid, :pid, 1);
\set ON_ERROR_STOP on
