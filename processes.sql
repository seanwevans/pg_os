-------------
-- PROCESSES
-------------

-- processes
CREATE TABLE IF NOT EXISTS processes (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    state TEXT NOT NULL CHECK (state IN ('new', 'ready', 'running', 'waiting', 'terminated')),
    priority INTEGER DEFAULT 1, -- Higher numbers = higher priority
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    owner_user_id INTEGER REFERENCES users(id),
    duration INTEGER DEFAULT 1,
    waiting_on_semaphore TEXT
);

-- process logs
CREATE TABLE IF NOT EXISTS process_logs (
    id SERIAL PRIMARY KEY,
    process_id INTEGER REFERENCES processes(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT now()
);




-- create a process
CREATE OR REPLACE PROCEDURE create_process(
    process_name TEXT,
    owner_id INTEGER,
    process_priority INTEGER DEFAULT 1
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- Permission check
    IF NOT check_permission(owner_id, 'process', 'execute') THEN
        RAISE EXCEPTION 'User % does not have permission to create a process', owner_id;
    END IF;

    -- Insert the process
    INSERT INTO processes (name, state, priority, owner_user_id, duration)
    VALUES (process_name, 'new', process_priority, owner_id, 1);
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Process name % already exists', process_name;
    WHEN others THEN
        RAISE EXCEPTION 'Could not create process: %', SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE start_process(user_id INTEGER, process_id INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- Permission check
    IF NOT check_permission(user_id, 'process', 'execute') THEN
        RAISE EXCEPTION 'User % does not have permission to start processes', user_id;
    END IF;

    -- Update the process state to 'ready' only if it's currently 'new'
    UPDATE processes
    SET state = 'ready', updated_at = now()
    WHERE id = process_id AND state = 'new';

    -- Check if the update was successful
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Process % is not in a valid state to be started', process_id;
    END IF;
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Failed to start process %: %', process_id, SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE execute_process(user_id INTEGER, process_id INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    exec_duration INTEGER;
BEGIN
    -- Permission check
    IF NOT check_permission(user_id, 'process', 'execute') THEN
        RAISE EXCEPTION 'User % does not have permission to execute processes', user_id;
    END IF;

    -- Check if the process is ready
    UPDATE processes
    SET state = 'running', updated_at = now()
    WHERE id = process_id AND state = 'ready';

    IF NOT FOUND THEN
        RAISE NOTICE 'Process % is not ready for execution', process_id;
        RETURN;
    END IF;

    -- Log the start
    PERFORM log_process_action(process_id, 'Execution started');

    -- Simulate work
    SELECT duration INTO exec_duration FROM processes WHERE id = process_id;
    IF exec_duration IS NULL OR exec_duration < 0 THEN
        exec_duration := 0;
    END IF;
    PERFORM pg_sleep(exec_duration);

    -- Mark process as terminated
    UPDATE processes
    SET state = 'terminated', updated_at = now()
    WHERE id = process_id;

    -- Log completion
    PERFORM log_process_action(process_id, 'Execution finished');
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Failed to execute process %: %', process_id, SQLERRM;
END;
$$;





-- list all processes by state
CREATE OR REPLACE FUNCTION list_processes_by_state(state_filter TEXT)
RETURNS SETOF processes AS $$
BEGIN
    RETURN QUERY SELECT * FROM processes WHERE state = state_filter;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


-- list all running or ready processes by priority
CREATE OR REPLACE FUNCTION list_ready_or_running_processes()
RETURNS SETOF processes AS $$
BEGIN
    RETURN QUERY SELECT * FROM processes WHERE state IN ('ready', 'running') ORDER BY priority DESC, created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


CREATE OR REPLACE FUNCTION set_process_priority(user_id INTEGER, process_id INTEGER, new_priority INTEGER) RETURNS VOID AS $$
BEGIN
    -- Permission check
    IF NOT check_permission(user_id, 'process', 'execute') THEN
        RAISE EXCEPTION 'User % does not have permission to set process priority', user_id;
    END IF;

    UPDATE processes SET priority = new_priority, updated_at = now()
    WHERE id = process_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


CREATE OR REPLACE FUNCTION terminate_process(user_id INTEGER, process_id INTEGER) RETURNS VOID AS $$
BEGIN
    -- Permission check
    IF NOT check_permission(user_id, 'process', 'execute') THEN
        RAISE EXCEPTION 'User % does not have permission to terminate processes', user_id;
    END IF;

    UPDATE processes
    SET state = 'terminated', updated_at = now()
    WHERE id = process_id AND state != 'terminated';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


-- log process
CREATE OR REPLACE FUNCTION log_process_action(process_id INTEGER, action TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO process_logs (process_id, action) VALUES (process_id, action);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


-- count states
CREATE OR REPLACE FUNCTION process_count_by_state() RETURNS TABLE(state TEXT, count INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT state, COUNT(*) FROM processes GROUP BY state;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


CREATE OR REPLACE FUNCTION pause_all_processes(user_id INTEGER) RETURNS VOID AS $$
BEGIN
    -- Permission check
    IF NOT check_permission(user_id, 'process', 'execute') THEN
        RAISE EXCEPTION 'User % does not have permission to pause processes', user_id;
    END IF;

    UPDATE processes SET state = 'waiting', updated_at = now()
    WHERE state IN ('ready', 'running');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


CREATE OR REPLACE FUNCTION resume_all_waiting_processes(user_id INTEGER) RETURNS VOID AS $$
BEGIN
    -- Permission check
    IF NOT check_permission(user_id, 'process', 'execute') THEN
        RAISE EXCEPTION 'User % does not have permission to resume processes', user_id;
    END IF;

    UPDATE processes SET state = 'ready', updated_at = now()
    WHERE state = 'waiting';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
