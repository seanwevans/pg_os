-- tests for create_process
SET client_min_messages TO warning;
\i :abs_srcdir/../usersrolespermissions.sql
\set VERBOSITY terse

-- processes table and simplified create_process procedure
CREATE TABLE processes (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    state TEXT NOT NULL,
    priority INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    owner_user_id INTEGER REFERENCES users(id),
    duration INTEGER DEFAULT 1
);

CREATE OR REPLACE PROCEDURE create_process(
    process_name TEXT,
    owner_id INTEGER,
    process_priority INTEGER DEFAULT 1
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO processes (name, state, priority, owner_user_id, duration)
    VALUES (process_name, 'new', process_priority, owner_id, 1);
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Process name % already exists', process_name;
END;
$$;

-- setup: create user
SELECT create_user('carol') AS user_id;

-- successful process creation
CALL create_process('proc_ok', 2, 5);
SELECT name, state, priority, owner_user_id FROM processes;

\set ON_ERROR_STOP off
-- duplicate process name should fail
CALL create_process('proc_ok', 2, 5);
-- invalid owner should fail
CALL create_process('other', 999, 1);
\set ON_ERROR_STOP on
