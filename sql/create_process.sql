-- tests for create_process
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup: create user with permission
SELECT create_user('carol') AS carol_id \gset
SELECT create_role('executor') AS role_id \gset
SELECT assign_role_to_user(:carol_id, :role_id);
SELECT grant_permission_to_role(:role_id, 'process', 'execute');

-- successful process creation
CALL create_process('proc_ok', :carol_id, 5);
SELECT name, state, priority, owner_user_id FROM processes;

\set ON_ERROR_STOP off
-- duplicate process name should fail
CALL create_process('proc_ok', :carol_id, 5);
-- invalid owner should fail
CALL create_process('other', 999, 1);
\set ON_ERROR_STOP on
