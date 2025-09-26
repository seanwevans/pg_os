\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;

-- setup: create user and files
INSERT INTO users (username) VALUES ('alice');
INSERT INTO files (id, name, owner_user_id, permissions, is_directory)
VALUES (1, 'test.txt', 1, 'rwxr-----', false);
INSERT INTO files (id, name, owner_user_id, permissions, is_directory)
VALUES (2, 'test2.txt', 1, 'rwxr-----', false);
INSERT INTO roles (role_name) VALUES ('file_rw');
INSERT INTO permissions (role_id, resource_type, action)
VALUES (1, 'file', 'read'), (1, 'file', 'write');
INSERT INTO user_roles (user_id, role_id) VALUES (1, 1);
\set ECHO queries
\set VERBOSITY terse

-- successful lock
SELECT lock_file(1, 1, 'read');

-- ensure multiple locks can coexist
SELECT lock_file(1, 2, 'read');

\set ON_ERROR_STOP off
SELECT lock_file(1, 1, 'read');
SELECT lock_file(1, 999, 'read');
SELECT lock_file(1, 2, 'bad');
\set ON_ERROR_STOP on

-- unlock one file and ensure other lock remains
SELECT unlock_file(1, 1);
SELECT file_id, locked_by_user, lock_mode FROM file_locks ORDER BY file_id;
