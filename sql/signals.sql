-- tests for send_signal / handle_signals
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup: a user that may execute processes, plus a running process
SELECT create_user('signaler') AS uid \gset
SELECT create_role('sig_role') AS rid \gset
SELECT assign_role_to_user(:uid, :rid);
SELECT grant_permission_to_role(:rid, 'process', 'execute');
INSERT INTO processes (name, state, owner_user_id)
VALUES ('sig_proc', 'running', :uid)
RETURNING id AS pid \gset

-- SIGSTOP pauses a running process
SELECT send_signal(:pid, 'SIGSTOP');
SELECT handle_signals(:uid, :pid);
SELECT state FROM processes WHERE id = :pid;

-- SIGCONT moves a waiting process back to ready
SELECT send_signal(:pid, 'SIGCONT');
SELECT handle_signals(:uid, :pid);
SELECT state FROM processes WHERE id = :pid;

-- SIGTERM terminates the process
SELECT send_signal(:pid, 'SIGTERM');
SELECT handle_signals(:uid, :pid);
SELECT state FROM processes WHERE id = :pid;

-- handled signals are consumed
SELECT count(*) AS remaining_signals FROM signals WHERE process_id = :pid;
