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
    UPDATE modules
    SET loaded = TRUE
    WHERE modules.module_name = load_module.module_name;
    -- In practice, you'd dynamically execute code or extend functionality
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION load_module(TEXT) OWNER TO pg_os_admin;

CREATE OR REPLACE FUNCTION unload_module(module_name TEXT) RETURNS VOID AS $$
BEGIN
    UPDATE modules
    SET loaded = FALSE
    WHERE modules.module_name = unload_module.module_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION unload_module(TEXT) OWNER TO pg_os_admin;
