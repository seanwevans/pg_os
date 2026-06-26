-- The extension must work when installed into a non-default schema and called
-- WITHOUT that schema on the search_path. Every function pins its own
-- search_path to @extschema@, so qualified calls resolve their tables.
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
DROP SCHEMA IF EXISTS pgos_ext CASCADE;
CREATE SCHEMA pgos_ext;
CREATE EXTENSION pg_os WITH SCHEMA pgos_ext;
-- Deliberately keep pgos_ext OFF the search_path.
SET search_path = public;
\set ECHO queries
\set VERBOSITY terse

-- users / roles / permissions / process
SELECT pgos_ext.create_user('alice') AS uid \gset
SELECT pgos_ext.create_role('ops') AS rid \gset
SELECT pgos_ext.assign_role_to_user(:uid, :rid);
SELECT pgos_ext.grant_permission_to_role(:rid, 'process', 'execute');
SELECT pgos_ext.grant_permission_to_role(:rid, 'memory', 'allocate');
SELECT pgos_ext.grant_permission_to_role(:rid, 'file', 'write');
CALL pgos_ext.create_process('p1', :uid, 1);
SELECT name, state FROM pgos_ext.processes ORDER BY name;

-- memory
INSERT INTO pgos_ext.memory_segments (size) VALUES (4096);
SELECT pgos_ext.allocate_memory(:uid, 1, 1024);
SELECT allocated, allocated_to FROM pgos_ext.memory_segments ORDER BY id;

-- filesystem
SELECT pgos_ext.create_file(:uid, 'f.txt', NULL, FALSE) AS fid \gset
SELECT pgos_ext.write_file(:uid, :fid, 'hi');
SELECT pgos_ext.read_file(:uid, :fid);

-- a SECURITY DEFINER helper resolves its tables the same way
SELECT pgos_ext.create_mutex('m');
SELECT name, locked_by_thread FROM pgos_ext.mutexes;

-- clean up so later tests get a fresh public-schema install
\set ECHO none
DROP EXTENSION pg_os CASCADE;
DROP SCHEMA pgos_ext CASCADE;
