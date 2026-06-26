-- tests for the process and thread schedulers
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup: a user allowed to execute processes
SELECT create_user('sched_user') AS uid \gset
SELECT create_role('sched_role') AS rid \gset
SELECT assign_role_to_user(:uid, :rid);
SELECT grant_permission_to_role(:rid, 'process', 'execute');

-- a ready process is driven to completion by the scheduler
INSERT INTO processes (name, state, priority, owner_user_id)
VALUES ('sched_proc', 'ready', 5, :uid)
RETURNING id AS pid \gset
SELECT schedule_processes(:uid);
SELECT state FROM processes WHERE id = :pid;

-- the thread scheduler drains ready threads (and terminates, no infinite loop)
INSERT INTO threads (process_id, name, state)
VALUES (:pid, 'sched_thread', 'ready')
RETURNING id AS tid \gset
SELECT schedule_threads();
SELECT state FROM threads WHERE id = :tid;
SELECT count(*) AS ready_threads FROM threads WHERE state = 'ready';
