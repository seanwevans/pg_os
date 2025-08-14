-------------
-- SCHEDULER
-------------

-- scheduler configurations
CREATE TABLE IF NOT EXISTS scheduler_config (
    id SERIAL PRIMARY KEY,
    policy TEXT NOT NULL CHECK (policy IN ('priority', 'round_robin', 'sjf')),
    time_quantum INTEGER DEFAULT 1,  -- For round-robin
    updated_at TIMESTAMP DEFAULT now(),
    is_real_time BOOLEAN DEFAULT FALSE
);

-- threads
CREATE TABLE IF NOT EXISTS threads (
    id SERIAL PRIMARY KEY,
    process_id INTEGER NOT NULL REFERENCES processes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    state TEXT CHECK (state IN ('new', 'ready', 'running', 'waiting', 'terminated')) DEFAULT 'new',
    priority INTEGER DEFAULT 1,
    waiting_on_mutex TEXT,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);


-- Insert a default configuration (priority-based)
INSERT INTO scheduler_config (policy) VALUES ('priority')
ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION schedule_processes(user_id INTEGER) RETURNS VOID AS $$
DECLARE
    cfg RECORD;
    next_process RECORD;
BEGIN
    SELECT * INTO cfg FROM scheduler_config ORDER BY id DESC LIMIT 1;

    IF NOT FOUND THEN
        RAISE NOTICE 'No scheduler configuration found. Using priority as default.';
        cfg.policy := 'priority';
    END IF;

    LOOP
        IF cfg.policy = 'priority' THEN
            -- Find the next 'ready' process by priority
            SELECT * INTO next_process
            FROM processes
            WHERE state = 'ready'
            ORDER BY priority DESC, created_at
            LIMIT 1;

        ELSIF cfg.policy = 'round_robin' THEN
            -- For round-robin, pick the earliest ready process by updated_at
            -- Could store a "last_scheduled" column to rotate through processes
            SELECT * INTO next_process
            FROM processes
            WHERE state = 'ready'
            ORDER BY updated_at
            LIMIT 1;

            -- After execution, we might update a round-robin "last_scheduled" column.

        ELSIF cfg.policy = 'sjf' THEN
            -- Shortest Job First: assume shortest job based on some metadata, e.g., a 'duration' column
            -- If you add a 'duration' column to processes, you can do:
            -- SELECT * INTO next_process FROM processes WHERE state='ready' ORDER BY duration LIMIT 1;
            -- Here we just simulate by using priority as a placeholder.
            SELECT * INTO next_process
            FROM processes
            WHERE state = 'ready'
            ORDER BY priority ASC, created_at
            LIMIT 1;
        END IF;

        -- Exit if no ready processes are found
        IF NOT FOUND THEN
            EXIT;
        END IF;

        -- Execute the chosen process
        CALL execute_process(user_id, next_process.id);

    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION schedule_processes(INTEGER) OWNER TO pg_os_admin;


-- thread scheduler
CREATE OR REPLACE FUNCTION schedule_threads() RETURNS VOID AS $$
DECLARE
    next_thread RECORD;
BEGIN
    LOOP
        SELECT * INTO next_thread
        FROM threads
        WHERE state='ready'
        ORDER BY priority DESC, created_at
        LIMIT 1;

        EXIT WHEN NOT FOUND;

        -- Simulate thread execution
        UPDATE threads SET state='running', updated_at=now() WHERE id=next_thread.id;
        PERFORM pg_sleep(0.1); -- simulate shorter execution
        UPDATE threads SET state='ready', updated_at=now() WHERE id=next_thread.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION schedule_threads() OWNER TO pg_os_admin;
