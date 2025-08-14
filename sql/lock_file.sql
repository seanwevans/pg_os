\set ECHO none
SET client_min_messages TO warning;
\i :abs_srcdir/../usersrolespermissions.sql
\i :abs_srcdir/../fs.sql

-- setup: create user and files
INSERT INTO users (username)
SELECT 'alice'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'alice');
INSERT INTO files (id, name, owner_user_id, permissions, is_directory)
VALUES (1, 'test.txt', 1, 'rwxr-----', false);
INSERT INTO files (id, name, owner_user_id, permissions, is_directory)
VALUES (2, 'test2.txt', 1, 'rwxr-----', false);
INSERT INTO roles (id, role_name) VALUES (1, 'file_rw');
INSERT INTO permissions (role_id, resource_type, action)
VALUES (1, 'file', 'read'), (1, 'file', 'write');
INSERT INTO user_roles (user_id, role_id) VALUES (1, 1);
\set ECHO queries
\set VERBOSITY terse

-- successful lock
SELECT lock_file(1, 1, 'read');

\set ON_ERROR_STOP off
SELECT lock_file(1, 1, 'read');
SELECT lock_file(1, 999, 'read');
SELECT lock_file(1, 2, 'bad');
\set ON_ERROR_STOP on
