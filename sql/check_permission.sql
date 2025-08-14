\set ECHO none
SET client_min_messages TO warning;
DROP SCHEMA IF EXISTS pgos_test CASCADE;
CREATE SCHEMA pgos_test;
SET search_path TO pgos_test;
\i :abs_srcdir/../pg_os--1.0.sql

-- setup users, role and permissions
SELECT create_user('alice') AS alice_id \gset
SELECT create_user('bob') AS bob_id \gset
SELECT create_role('executor') AS role_id \gset
\o /dev/null
SELECT assign_role_to_user(:alice_id, :role_id);
SELECT grant_permission_to_role(:role_id, 'process', 'execute');
\o

\set ECHO queries
\set VERBOSITY terse

-- permission checks
SELECT check_permission(1, 'process', 'execute') AS alice_allowed;
SELECT check_permission(2, 'process', 'execute') AS bob_allowed;

-- authorized process creation
CALL create_process('alice_proc', 1);

-- unauthorized process creation should fail
\set ON_ERROR_STOP off
CALL create_process('bob_proc', 2);
\set ON_ERROR_STOP on

-- verify only authorized process exists
SELECT name, owner_user_id FROM processes ORDER BY name;
