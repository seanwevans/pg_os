-- tests for memory allocation
\set ECHO none
SET client_min_messages TO warning;

\i :abs_srcdir/../usersrolespermissions.sql

-- simplified memory tables and functions for testing
CREATE TABLE memory_segments (
    id SERIAL PRIMARY KEY,
    size INTEGER NOT NULL,
    allocated BOOLEAN DEFAULT FALSE,
    allocated_to INTEGER
);

CREATE TABLE process_memory (
    process_id INTEGER,
    segment_id INTEGER,
    PRIMARY KEY (process_id, segment_id)
);

CREATE TABLE memory_logs (
    id SERIAL PRIMARY KEY,
    process_id INTEGER,
    action TEXT,
    performed_by INTEGER,
    segment_id INTEGER
);

CREATE OR REPLACE FUNCTION log_memory_action(process_id INTEGER, action TEXT, user_id INTEGER, segment_id INTEGER)
RETURNS VOID AS $$
BEGIN
    INSERT INTO memory_logs (process_id, action, performed_by, segment_id)
    VALUES (process_id, action, user_id, segment_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION allocate_memory(user_id INTEGER, process_id INTEGER, segment_size INTEGER)
RETURNS VOID AS $$
DECLARE
    seg RECORD;
BEGIN
    IF NOT check_permission(user_id, 'memory', 'allocate') THEN
        RAISE EXCEPTION 'User % does not have permission to allocate memory', user_id;
    END IF;

    SELECT * INTO seg FROM memory_segments
    WHERE allocated = FALSE AND size >= segment_size
    ORDER BY size
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No suitable memory segment available of size %', segment_size;
    END IF;

    UPDATE memory_segments SET allocated = TRUE, allocated_to = process_id WHERE id = seg.id;
    INSERT INTO process_memory (process_id, segment_id) VALUES (process_id, seg.id);
    PERFORM log_memory_action(process_id, 'allocated', user_id, seg.id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION free_memory(user_id INTEGER, process_id INTEGER, segment_id INTEGER)
RETURNS VOID AS $$
BEGIN
    IF NOT check_permission(user_id, 'memory', 'allocate') THEN
        RAISE EXCEPTION 'User % does not have permission to allocate memory', user_id;
    END IF;

    DELETE FROM process_memory pm
      WHERE pm.process_id = free_memory.process_id AND pm.segment_id = free_memory.segment_id;
    UPDATE memory_segments ms
      SET allocated = FALSE, allocated_to = NULL
      WHERE ms.id = free_memory.segment_id;
    PERFORM log_memory_action(process_id, 'freed', user_id, segment_id);
END;
$$ LANGUAGE plpgsql;

-- setup: grant memory allocation permission and memory segment
INSERT INTO roles (id, role_name) VALUES (2, 'mem_role');
INSERT INTO permissions (role_id, resource_type, action) VALUES (2, 'memory', 'allocate');
INSERT INTO user_roles (user_id, role_id) VALUES (2, 2);
INSERT INTO memory_segments (size) VALUES (1024);

\set ECHO queries
\set VERBOSITY terse

-- successful allocation
SELECT allocate_memory(2, 1, 512);
SELECT process_id, segment_id FROM process_memory;

\set ON_ERROR_STOP off
-- allocation without permission should fail
SELECT allocate_memory(1, 1, 512);
\set ON_ERROR_STOP on

-- free memory
SELECT free_memory(2, 1, 1);
SELECT count(*) FROM process_memory;
