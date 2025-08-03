SET client_min_messages TO warning;
\i :abs_srcdir/../usersrolespermissions.sql
\i :abs_srcdir/../fs.sql
\set VERBOSITY terse

-- setup: create user and files
INSERT INTO users (username)
SELECT 'alice'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'alice');
INSERT INTO files (id, name, owner_user_id, permissions, is_directory)
VALUES (1, 'test.txt', 1, 'rwxr-----', false);
INSERT INTO files (id, name, owner_user_id, permissions, is_directory)
VALUES (2, 'test2.txt', 1, 'rwxr-----', false);

-- successful lock
SELECT lock_file(1, 1, 'read');

\set ON_ERROR_STOP off
-- duplicate lock should fail
SELECT lock_file(1, 1, 'read');

-- non-existent file should fail
SELECT lock_file(1, 999, 'read');

-- invalid mode should fail
SELECT lock_file(1, 2, 'bad');
\set ON_ERROR_STOP on
