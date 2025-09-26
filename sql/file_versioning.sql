-- tests for file versioning on repeated writes
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup: create writer user with file write permission
SELECT create_user('writer') AS writer_id \gset
SELECT create_role('file_writer') AS role_id \gset
SELECT assign_role_to_user(:writer_id, :role_id);
SELECT grant_permission_to_role(:role_id, 'file', 'write');

-- create a file owned by the writer
SELECT create_file(:writer_id, 'versioned.txt', NULL, FALSE) AS file_id \gset

-- write twice, generating two versions
SELECT write_file(:writer_id, :file_id, 'first revision');
SELECT write_file(:writer_id, :file_id, 'second revision');

-- ensure versions capture each prior state
SELECT file_id, version_number, contents
  FROM file_versions
 WHERE file_id = :file_id
 ORDER BY version_number;
