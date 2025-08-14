-- tests for load_module and unload_module
\set ECHO none
SET client_min_messages TO warning;

-- modules table and functions
CREATE TABLE modules (
    id SERIAL PRIMARY KEY,
    module_name TEXT UNIQUE NOT NULL,
    loaded BOOLEAN DEFAULT FALSE,
    code TEXT,
    created_at TIMESTAMP DEFAULT now()
);

CREATE OR REPLACE FUNCTION load_module(module_name TEXT) RETURNS VOID AS $$
BEGIN
    UPDATE modules
    SET loaded = TRUE
    WHERE modules.module_name = load_module.module_name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION unload_module(module_name TEXT) RETURNS VOID AS $$
BEGIN
    UPDATE modules
    SET loaded = FALSE
    WHERE modules.module_name = unload_module.module_name;
END;
$$ LANGUAGE plpgsql;

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

