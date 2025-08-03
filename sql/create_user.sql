\i :abs_srcdir/../usersrolespermissions.sql
\set VERBOSITY terse

-- successful creation
SELECT create_user('alice') AS user_id;

\set ON_ERROR_STOP off
-- duplicate username should fail
SELECT create_user('alice');

-- null username should fail
SELECT create_user(NULL);
\set ON_ERROR_STOP on
ALTER SEQUENCE users_id_seq RESTART WITH 2;
