-----------
-- MODULES
-----------

CREATE TABLE IF NOT EXISTS modules (
    id SERIAL PRIMARY KEY,
    module_name TEXT UNIQUE NOT NULL,
    loaded BOOLEAN DEFAULT FALSE,
    code TEXT,
    created_at TIMESTAMP DEFAULT now()
);

CREATE OR REPLACE FUNCTION load_module(module_name TEXT) RETURNS VOID AS $$
BEGIN
    UPDATE modules SET loaded=TRUE WHERE module_name=module_name;
    -- In practice, you'd dynamically execute code or extend functionality
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION unload_module(module_name TEXT) RETURNS VOID AS $$
BEGIN
    UPDATE modules SET loaded=FALSE WHERE module_name=module_name;
END;
$$ LANGUAGE plpgsql;
