-- tests for load_module and unload_module
\set ECHO none
SET client_min_messages TO warning;

DROP TABLE IF EXISTS modules CASCADE;

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
