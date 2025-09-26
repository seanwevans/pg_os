-- tests for create_file parent validation
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup user with file write permission
INSERT INTO users (username) VALUES ('alice');
INSERT INTO roles (role_name) VALUES ('file_writer');
INSERT INTO permissions (role_id, resource_type, action)
VALUES (1, 'file', 'write');
INSERT INTO user_roles (user_id, role_id) VALUES (1, 1);

-- create a non-directory parent entry
INSERT INTO files (id, name, owner_user_id, permissions, is_directory)
VALUES (1, 'not_a_directory', 1, 'rwxr-----', false);

\set ON_ERROR_STOP off
SELECT create_file(1, 'child', 1, FALSE);
\set ON_ERROR_STOP on
