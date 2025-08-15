\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- successful creation
SELECT create_user('alice') AS user_id;

\set ON_ERROR_STOP off
-- duplicate username should fail
SELECT create_user('alice');

-- null username should fail
SELECT create_user(NULL);

-- empty username is allowed by the extension
SELECT create_user('');
\set ON_ERROR_STOP on
