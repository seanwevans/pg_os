-- tests for load_module and unload_module
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;

INSERT INTO modules (module_name) VALUES ('mod1'), ('mod2');

\set ECHO queries
\set VERBOSITY terse

-- initial state
SELECT module_name, loaded FROM modules ORDER BY id;

-- load mod1
SELECT load_module('mod1');
SELECT module_name, loaded FROM modules ORDER BY id;

-- unload mod1
SELECT unload_module('mod1');
SELECT module_name, loaded FROM modules ORDER BY id;

-- load non-existent module
SELECT load_module('mod3');
SELECT module_name, loaded FROM modules ORDER BY id;

-- load mod2
SELECT load_module('mod2');
SELECT module_name, loaded FROM modules ORDER BY id;
