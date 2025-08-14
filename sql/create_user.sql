\set ECHO none
\i :abs_srcdir/../usersrolespermissions.sql
\set ECHO queries
\set VERBOSITY terse

-- successful creation
SELECT create_user('alice') AS user_id;

\set ON_ERROR_STOP off
-- duplicate username should fail
SELECT create_user('alice');

-- null username should fail
SELECT create_user(NULL);

-- empty username should fail
SELECT create_user('');
\set ON_ERROR_STOP on
ALTER SEQUENCE users_id_seq RESTART WITH 2;
