---------
-- AUDIT
---------

-- logs
CREATE TABLE IF NOT EXISTS file_logs (
    id SERIAL PRIMARY KEY,
    file_id INTEGER REFERENCES files(id),
    action TEXT NOT NULL,
    performed_by INTEGER REFERENCES users(id),
    timestamp TIMESTAMP DEFAULT now()
);

-- memory logs
CREATE TABLE IF NOT EXISTS memory_logs (
    id SERIAL PRIMARY KEY,
    process_id INTEGER REFERENCES processes(id),
    action TEXT NOT NULL,
    performed_by INTEGER REFERENCES users(id),
    segment_id INTEGER,
    timestamp TIMESTAMP DEFAULT now()
);

-- faults
CREATE TABLE IF NOT EXISTS faults (
    id SERIAL PRIMARY KEY,
    process_id INTEGER REFERENCES processes(id),
    fault_type TEXT CHECK (fault_type IN('segfault','arithmetic','io','other')),
    timestamp TIMESTAMP DEFAULT now()
);

-- Checkpoints
CREATE TABLE IF NOT EXISTS checkpoints (
    id SERIAL PRIMARY KEY,
    process_id INTEGER REFERENCES processes(id),
    state_snapshot TEXT,
    created_at TIMESTAMP DEFAULT now()
);



-- log for files
CREATE OR REPLACE FUNCTION log_file_action(file_id INTEGER, action TEXT, user_id INTEGER) RETURNS VOID AS $$
BEGIN
    INSERT INTO file_logs (file_id, action, performed_by) VALUES (file_id, action, user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION log_file_action(INTEGER, TEXT, INTEGER) OWNER TO pg_os_admin;


-- log for memory
CREATE OR REPLACE FUNCTION log_memory_action(process_id INTEGER, action TEXT, user_id INTEGER, segment_id INTEGER) RETURNS VOID AS $$
BEGIN
    INSERT INTO memory_logs (process_id, action, performed_by, segment_id) VALUES (process_id, action, user_id, segment_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION log_memory_action(INTEGER, TEXT, INTEGER, INTEGER) OWNER TO pg_os_admin;





-- Update file operations to log actions
CREATE OR REPLACE FUNCTION write_file(user_id INTEGER, file_id INTEGER, data TEXT) RETURNS VOID AS $$
DECLARE
    f RECORD;
BEGIN
    SELECT * INTO f FROM files WHERE id = file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    IF f.is_directory THEN
        RAISE EXCEPTION 'Cannot write to a directory';
    END IF;

    IF f.owner_user_id = user_id THEN
        IF substring(f.permissions from 1 for 3) NOT LIKE '%w%' THEN
            RAISE EXCEPTION 'Owner does not have write permission on this file';
        END IF;
    ELSIF NOT check_permission(user_id, 'file', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to write files', user_id;
    END IF;

    BEGIN
        UPDATE files SET contents = data WHERE id = file_id;
        PERFORM log_file_action(file_id, 'write', user_id);
    EXCEPTION WHEN others THEN
        RAISE EXCEPTION 'Error writing to file: %', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION write_file(INTEGER, INTEGER, TEXT) OWNER TO pg_os_admin;


-- On fault, record the fault and possibly rollback to a checkpoint
CREATE OR REPLACE FUNCTION handle_fault(process_id INTEGER, fault_type TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO faults (process_id, fault_type) VALUES (process_id, fault_type);
    -- Recovery logic would go here, like restoring from a checkpoint
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION handle_fault(INTEGER, TEXT) OWNER TO pg_os_admin;
