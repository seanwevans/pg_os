-- tests for load_module and unload_module
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup: insert module
INSERT INTO modules (module_name) VALUES ('test_module');

-- check default state
SELECT module_name, loaded FROM modules WHERE module_name = 'test_module';

-- load module
SELECT load_module('test_module');
SELECT module_name, loaded FROM modules WHERE module_name = 'test_module';

-- unload module
SELECT unload_module('test_module');
SELECT module_name, loaded FROM modules WHERE module_name = 'test_module';
