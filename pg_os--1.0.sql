-- USER, ROLES & PERMISSIONS
-----------------------------


-- users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    role_name TEXT UNIQUE NOT NULL
);

-- user roles
CREATE TABLE IF NOT EXISTS user_roles (
    user_id INTEGER NOT NULL REFERENCES users(id),
    role_id INTEGER NOT NULL REFERENCES roles(id),
    PRIMARY KEY (user_id, role_id)
);

-- permissions
CREATE TABLE IF NOT EXISTS permissions (
    id SERIAL PRIMARY KEY,
    role_id INTEGER NOT NULL REFERENCES roles(id),
    resource_type TEXT NOT NULL CHECK (resource_type IN ('process', 'file', 'resource', 'memory')),
    action TEXT NOT NULL CHECK (action IN ('read','write','execute','allocate','delete'))
);

-- groups
CREATE TABLE IF NOT EXISTS groups (
    id SERIAL PRIMARY KEY,
    group_name TEXT UNIQUE NOT NULL
);

-- user groups
CREATE TABLE IF NOT EXISTS user_groups (
    user_id INTEGER REFERENCES users(id),
    group_id INTEGER REFERENCES groups(id),
    PRIMARY KEY(user_id, group_id)
);

-- group permissions
CREATE TABLE IF NOT EXISTS group_permissions (
    id SERIAL PRIMARY KEY,
    group_id INTEGER REFERENCES groups(id),
    resource_type TEXT NOT NULL CHECK (resource_type IN ('process', 'file', 'resource', 'memory')),
    action TEXT NOT NULL CHECK (action IN ('read','write','execute','allocate','delete'))
);



-- create a user
CREATE OR REPLACE FUNCTION create_user(name TEXT) RETURNS INTEGER AS $$
DECLARE
    new_user_id INTEGER;
BEGIN
    INSERT INTO users (username) VALUES (name) RETURNING id INTO new_user_id;
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;


-- create a role
CREATE OR REPLACE FUNCTION create_role(role_name TEXT) RETURNS INTEGER AS $$
DECLARE
    new_role_id INTEGER;
BEGIN
    INSERT INTO roles (role_name) VALUES (role_name) RETURNING id INTO new_role_id;
    RETURN new_role_id;
END;
$$ LANGUAGE plpgsql;


-- Assign a role to a user
CREATE OR REPLACE FUNCTION assign_role_to_user(user_id INTEGER, role_id INTEGER) RETURNS VOID AS $$
BEGIN
    INSERT INTO user_roles (user_id, role_id) VALUES (user_id, role_id);
END;
$$ LANGUAGE plpgsql;


-- Grant permission to a role
CREATE OR REPLACE FUNCTION grant_permission_to_role(role_id INTEGER, resource_type TEXT, action TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO permissions (role_id, resource_type, action) VALUES (role_id, resource_type, action);
END;
$$ LANGUAGE plpgsql;


-- check permissions
CREATE OR REPLACE FUNCTION check_permission(user_id INTEGER, resource_type TEXT, action TEXT) RETURNS BOOLEAN AS $$
DECLARE
    allowed BOOLEAN;
BEGIN
    -- First check user roles
    SELECT TRUE INTO allowed
    FROM user_roles ur
    JOIN permissions p ON ur.role_id = p.role_id
    WHERE ur.user_id = user_id
      AND p.resource_type = resource_type
      AND p.action = action
    LIMIT 1;

    IF allowed THEN
        RETURN TRUE;
    END IF;

    -- If not allowed by user roles, check group permissions
    SELECT TRUE INTO allowed
    FROM user_groups ug
    JOIN group_permissions gp ON ug.group_id = gp.group_id
    WHERE ug.user_id = user_id
      AND gp.resource_type = resource_type
      AND gp.action = action
    LIMIT 1;

    RETURN COALESCE(allowed, FALSE);
END;
$$ LANGUAGE plpgsql;
-------------
-- PROCESSES
-------------

-- processes
CREATE TABLE processes (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('new', 'ready', 'running', 'waiting', 'terminated')),
    priority INTEGER DEFAULT 1, -- Higher numbers = higher priority
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    owner_user_id INTEGER REFERENCES users(id),
    duration INTEGER DEFAULT 1
);

-- process logs
CREATE TABLE IF NOT EXISTS process_logs (
    id SERIAL PRIMARY KEY,
    process_id INTEGER REFERENCES processes(id),
    action TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT now()
);

-- log process
CREATE OR REPLACE FUNCTION log_process_action(process_id INTEGER, action TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO process_logs (process_id, action) VALUES (process_id, action);
END;
$$ LANGUAGE plpgsql;

-- create a process
CREATE OR REPLACE PROCEDURE create_process(
    process_name TEXT, 
    owner_id INTEGER, 
    process_priority INTEGER DEFAULT 1
)
LANGUAGE plpgsql
AS $$
BEGIN
    BEGIN TRANSACTION;
    
    -- Permission check
    IF NOT check_permission(owner_id, 'process', 'execute') THEN
        RAISE EXCEPTION 'User % does not have permission to create a process', owner_id;
    END IF;

    -- Insert the process
    INSERT INTO processes (name, state, priority, owner_user_id, duration)
    VALUES (process_name, 'new', process_priority, owner_id, 1);

    -- Commit transaction
    COMMIT;
EXCEPTION
    WHEN unique_violation THEN
        ROLLBACK;
        RAISE EXCEPTION 'Process name % already exists', process_name;
    WHEN others THEN
        ROLLBACK;
        RAISE EXCEPTION 'Could not create process: %', SQLERRM;
END;
$$;


-- start a process
CREATE OR REPLACE PROCEDURE start_process(process_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    BEGIN TRANSACTION;

    -- Update the process state to 'ready' only if it's currently 'new'
    UPDATE processes
    SET state = 'ready', updated_at = now()
    WHERE id = process_id AND state = 'new';

    -- Check if the update was successful
    IF NOT FOUND THEN
        ROLLBACK; -- Rollback if the process was not in the expected state
        RAISE EXCEPTION 'Process % is not in a valid state to be started', process_id;
    END IF;

    -- Commit the transaction if everything is successful
    COMMIT;
EXCEPTION
    WHEN others THEN
        -- Rollback the transaction in case of any errors
        ROLLBACK;
        RAISE EXCEPTION 'Failed to start process %: %', process_id, SQLERRM;
END;
$$;


-- execute a process
CREATE OR REPLACE PROCEDURE execute_process(process_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    BEGIN TRANSACTION;

    -- Check if the process is ready
    UPDATE processes
    SET state = 'running', updated_at = now()
    WHERE id = process_id AND state = 'ready';

    IF NOT FOUND THEN
        ROLLBACK;
        RAISE NOTICE 'Process % is not ready for execution', process_id;
        RETURN;
    END IF;

    -- Log the start
    PERFORM log_process_action(process_id, 'Execution started');

    -- Simulate work
    PERFORM pg_sleep(1);

    -- Mark process as terminated
    UPDATE processes
    SET state = 'terminated', updated_at = now()
    WHERE id = process_id;

    -- Log completion
    PERFORM log_process_action(process_id, 'Execution finished');

    -- Commit transaction
    COMMIT;
EXCEPTION
    WHEN others THEN
        ROLLBACK;
        RAISE EXCEPTION 'Failed to execute process %: %', process_id, SQLERRM;
END;
$$;



-- schedule process
CREATE OR REPLACE PROCEDURE schedule_processes()
LANGUAGE plpgsql
AS $$
DECLARE
    cfg RECORD;
    next_process RECORD;
BEGIN
    -- Load scheduler configuration
    SELECT * INTO cfg FROM scheduler_config ORDER BY id DESC LIMIT 1;
    IF NOT FOUND THEN
        RAISE NOTICE 'No scheduler configuration found. Using priority as default.';
        cfg.policy := 'priority';
    END IF;

    LOOP
        -- Fetch next process based on policy
        IF cfg.policy = 'priority' THEN
            SELECT * INTO next_process
            FROM processes
            WHERE state = 'ready'
            ORDER BY priority DESC, created_at
            LIMIT 1;
        ELSIF cfg.policy = 'round_robin' THEN
            SELECT * INTO next_process
            FROM processes
            WHERE state = 'ready'
            ORDER BY updated_at
            LIMIT 1;
        ELSIF cfg.policy = 'sjf' THEN
            SELECT * INTO next_process
            FROM processes
            WHERE state = 'ready'
            ORDER BY duration, created_at
            LIMIT 1;
        END IF;

        IF NOT FOUND THEN
            EXIT;
        END IF;

        -- Execute the selected process in a transaction
        BEGIN TRANSACTION;
        PERFORM execute_process(next_process.id);
        COMMIT;
    END LOOP;
END;
$$;



-- list all processes by state
CREATE OR REPLACE FUNCTION list_processes_by_state(state_filter TEXT) 
RETURNS SETOF processes AS $$
BEGIN
    RETURN QUERY SELECT * FROM processes WHERE state = state_filter;
END;
$$ LANGUAGE plpgsql;


-- list all running or ready processes by priority
CREATE OR REPLACE FUNCTION list_ready_or_running_processes() 
RETURNS SETOF processes AS $$
BEGIN
    RETURN QUERY SELECT * FROM processes WHERE state IN ('ready', 'running') ORDER BY priority DESC, created_at;
END;
$$ LANGUAGE plpgsql;


-- set process priority
CREATE OR REPLACE FUNCTION set_process_priority(process_id INTEGER, new_priority INTEGER) RETURNS VOID AS $$
BEGIN
    UPDATE processes SET priority = new_priority, updated_at = now()
    WHERE id = process_id;
END;
$$ LANGUAGE plpgsql;


-- terminate process
CREATE OR REPLACE FUNCTION terminate_process(process_id INTEGER) RETURNS VOID AS $$
BEGIN
    UPDATE processes
    SET state = 'terminated', updated_at = now()
    WHERE id = process_id AND state != 'terminated';
END;
$$ LANGUAGE plpgsql;


-- count states
CREATE OR REPLACE FUNCTION process_count_by_state() RETURNS TABLE(state TEXT, count INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT state, COUNT(*) FROM processes GROUP BY state;
END;
$$ LANGUAGE plpgsql;


-- pause all processes
CREATE OR REPLACE FUNCTION pause_all_processes() RETURNS VOID AS $$
BEGIN
    UPDATE processes SET state = 'waiting', updated_at = now()
    WHERE state IN ('ready', 'running');
END;
$$ LANGUAGE plpgsql;


-- resume all waiting processes
CREATE OR REPLACE FUNCTION resume_all_waiting_processes() RETURNS VOID AS $$
BEGIN
    UPDATE processes SET state = 'ready', updated_at = now()
    WHERE state = 'waiting';
END;
$$ LANGUAGE plpgsql;
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
    process_id INTEGER NOT NULL REFERENCES processes(id),
    name TEXT NOT NULL,
    state TEXT CHECK (state IN ('new', 'ready', 'running', 'waiting', 'terminated')) DEFAULT 'new',
    priority INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);


-- Insert a default configuration (priority-based)
INSERT INTO scheduler_config (policy) VALUES ('priority')
ON CONFLICT DO NOTHING;
-- Modified scheduler function with switch based on policy
CREATE OR REPLACE FUNCTION schedule_processes() RETURNS VOID AS $$
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
        PERFORM execute_process(next_process.id);

    END LOOP;
END;
$$ LANGUAGE plpgsql;


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
$$ LANGUAGE plpgsql;
---------
-- LOCKS
---------

-- mutexes
CREATE TABLE IF NOT EXISTS mutexes (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    locked_by_thread INTEGER REFERENCES threads(id),
    created_at TIMESTAMP DEFAULT now()
);

-- semaphores
CREATE TABLE IF NOT EXISTS semaphores (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    count INTEGER NOT NULL CHECK (count >= 0),
    max_count INTEGER NOT NULL CHECK (max_count >= 1)
);



-- create a mutex
CREATE OR REPLACE FUNCTION create_mutex(mutex_name TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO mutexes (name) VALUES (mutex_name);
END;
$$ LANGUAGE plpgsql;


-- lock mutex
CREATE OR REPLACE FUNCTION lock_mutex(thread_id INTEGER, mutex_name TEXT) RETURNS VOID AS $$
DECLARE
    m RECORD;
BEGIN
    SELECT * INTO m FROM mutexes WHERE name = mutex_name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mutex % not found', mutex_name;
    END IF;

    IF m.locked_by_thread IS NULL THEN
        UPDATE mutexes SET locked_by_thread = thread_id WHERE id = m.id;
    ELSE
        -- Thread must wait
        UPDATE threads SET state = 'waiting', updated_at = now() WHERE id = thread_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- unlock mutex
CREATE OR REPLACE FUNCTION unlock_mutex(thread_id INTEGER, mutex_name TEXT) RETURNS VOID AS $$
DECLARE
    m RECORD;
    w RECORD;
BEGIN
    SELECT * INTO m FROM mutexes WHERE name = mutex_name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mutex % not found', mutex_name;
    END IF;

    IF m.locked_by_thread = thread_id THEN
        UPDATE mutexes SET locked_by_thread = NULL WHERE id = m.id;
        -- Wake up a waiting thread if any
        SELECT * INTO w FROM threads WHERE state='waiting' ORDER BY updated_at LIMIT 1;
        IF FOUND THEN
            UPDATE threads SET state='ready', updated_at=now() WHERE id=w.id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- create a semaphore
CREATE OR REPLACE FUNCTION create_semaphore(sem_name TEXT, initial_count INTEGER, max_val INTEGER) RETURNS VOID AS $$
BEGIN
    INSERT INTO semaphores (name, count, max_count)
    VALUES (sem_name, initial_count, max_val);
END;
$$ LANGUAGE plpgsql;


-- acquire a semaphore. If count is 0, the process must wait
CREATE OR REPLACE FUNCTION acquire_semaphore(process_id INTEGER, sem_name TEXT) RETURNS VOID AS $$
DECLARE
    sem RECORD;
BEGIN
    SELECT * INTO sem FROM semaphores WHERE name = sem_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Semaphore % not found', sem_name;
    END IF;

    IF sem.count > 0 THEN
        -- Acquire the semaphore immediately
        UPDATE semaphores SET count = count - 1 WHERE name = sem_name;
        PERFORM log_process_action(process_id, 'Semaphore acquired: ' || sem_name);
    ELSE
        -- No available resource, process must wait
        UPDATE processes SET state = 'waiting', updated_at = now() WHERE id = process_id;
        PERFORM log_process_action(process_id, 'Waiting for semaphore: ' || sem_name);
    END IF;
END;
$$ LANGUAGE plpgsql;


-- release a semaphore. If processes are waiting for this semaphore, one can be moved to ready
CREATE OR REPLACE FUNCTION release_semaphore(process_id INTEGER, sem_name TEXT) RETURNS VOID AS $$
DECLARE
    sem RECORD;
    waiting_proc RECORD;
BEGIN
    SELECT * INTO sem FROM semaphores WHERE name = sem_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Semaphore % not found', sem_name;
    END IF;

    IF sem.count < sem.max_count THEN
        UPDATE semaphores SET count = count + 1 WHERE name = sem_name;
        PERFORM log_process_action(process_id, 'Semaphore released: ' || sem_name);

        -- If any process is waiting for this semaphore, ready the oldest waiting process
        SELECT * INTO waiting_proc
        FROM processes
        WHERE state = 'waiting'
        ORDER BY updated_at
        LIMIT 1;

        IF FOUND THEN
            UPDATE processes SET state = 'ready', updated_at = now() WHERE id = waiting_proc.id;
            PERFORM log_process_action(waiting_proc.id, 'Process moved to ready due to semaphore release: ' || sem_name);
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;


-----------
-- SIGNALS
-----------

-- signals
CREATE TABLE IF NOT EXISTS signals (
    id SERIAL PRIMARY KEY,
    process_id INTEGER NOT NULL REFERENCES processes(id),
    signal_type TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT now()
);


-- send a signal to a process
CREATE OR REPLACE FUNCTION send_signal(target_process_id INTEGER, signal_type TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO signals (process_id, signal_type) VALUES (target_process_id, signal_type);
    PERFORM log_process_action(target_process_id, 'Signal received: ' || signal_type);
END;
$$ LANGUAGE plpgsql;



-- handle signals before execution. This can be called at the start of execute_process, or periodically by the scheduler
CREATE OR REPLACE FUNCTION handle_signals(process_id INTEGER) RETURNS VOID AS $$
DECLARE
    sig RECORD;
BEGIN
    FOR sig IN SELECT * FROM signals WHERE process_id = process_id LOOP
        IF sig.signal_type = 'SIGTERM' THEN
            PERFORM terminate_process(process_id);
        ELSIF sig.signal_type = 'SIGSTOP' THEN
            UPDATE processes SET state = 'waiting', updated_at = now() WHERE id = process_id AND state != 'terminated';
            PERFORM log_process_action(process_id, 'Process paused by signal');
        ELSIF sig.signal_type = 'SIGCONT' THEN
            UPDATE processes SET state = 'ready', updated_at = now() WHERE id = process_id AND state = 'waiting';
            PERFORM log_process_action(process_id, 'Process continued by signal');
        END IF;

        -- Remove the processed signal
        DELETE FROM signals WHERE id = sig.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
-----------------------------
----------
-- MEMORY
----------

-- memory segments
CREATE TABLE IF NOT EXISTS memory_segments (
    id SERIAL PRIMARY KEY,
    size INTEGER NOT NULL,
    allocated BOOLEAN DEFAULT FALSE,
    allocated_to INTEGER REFERENCES processes(id)
);


-- Represent pages and page tables
CREATE TABLE IF NOT EXISTS pages (
    id SERIAL PRIMARY KEY,
    size INTEGER NOT NULL DEFAULT 4096, -- 4KB pages for simulation
    allocated BOOLEAN DEFAULT FALSE,
    allocated_to_thread INTEGER REFERENCES threads(id)
);


CREATE TABLE IF NOT EXISTS page_tables (
    thread_id INTEGER REFERENCES threads(id),
    page_id INTEGER REFERENCES pages(id),
    virtual_address BIGINT,
    PRIMARY KEY (thread_id, virtual_address)
);


-- track how much memory is allocated per process
CREATE TABLE IF NOT EXISTS process_memory (
    process_id INTEGER REFERENCES processes(id),
    segment_id INTEGER REFERENCES memory_segments(id),
    PRIMARY KEY (process_id, segment_id)
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
-- log for memory
CREATE OR REPLACE FUNCTION log_memory_action(process_id INTEGER, action TEXT, user_id INTEGER, segment_id INTEGER) RETURNS VOID AS $$
BEGIN
    INSERT INTO memory_logs (process_id, action, performed_by, segment_id) VALUES (process_id, action, user_id, segment_id);
END;
$$ LANGUAGE plpgsql;

-- Similarly, for memory allocation, use transactions and more verbose errors
CREATE OR REPLACE FUNCTION allocate_memory(user_id INTEGER, process_id INTEGER, segment_size INTEGER) RETURNS VOID AS $$
DECLARE
    mem_seg RECORD;
BEGIN
    IF NOT check_permission(user_id, 'memory', 'allocate') THEN
        RAISE EXCEPTION 'User % does not have permission to allocate memory', user_id;
    END IF;

    BEGIN
        SELECT * INTO mem_seg FROM memory_segments
        WHERE allocated = FALSE AND size >= segment_size
        ORDER BY size
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No suitable memory segment available of size %', segment_size;
        END IF;

        -- Transaction block for atomic allocation
        PERFORM pg_advisory_lock(1);  -- simulate locking, ensure no other transaction interferes
        UPDATE memory_segments SET allocated = TRUE, allocated_to = process_id WHERE id = mem_seg.id;
        INSERT INTO process_memory (process_id, segment_id) VALUES (process_id, mem_seg.id);
        PERFORM pg_advisory_unlock(1);

        -- Log the allocation
        PERFORM log_memory_action(process_id, 'Memory allocated: segment ' || mem_seg.id, user_id, mem_seg.id);

    EXCEPTION WHEN others THEN
        RAISE EXCEPTION 'Error allocating memory: %', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;
 


-- Free memory from a process
CREATE OR REPLACE FUNCTION free_memory(user_id INTEGER, process_id INTEGER, segment_id INTEGER) RETURNS VOID AS $$
BEGIN
    IF NOT check_permission(user_id, 'memory', 'allocate') THEN
        RAISE EXCEPTION 'User % does not have permission to free memory', user_id;
    END IF;

    DELETE FROM process_memory WHERE process_id = process_id AND segment_id = segment_id;
    UPDATE memory_segments SET allocated = FALSE, allocated_to = NULL WHERE id = segment_id;
    PERFORM log_process_action(process_id, 'Memory freed: segment ' || segment_id);
END;
$$ LANGUAGE plpgsql;

-- allocate page to process
CREATE OR REPLACE FUNCTION allocate_page(thread_id INTEGER) RETURNS BIGINT AS $$
DECLARE
    p RECORD;
    virtual_addr BIGINT;
BEGIN
    -- Find a free page
    SELECT * INTO p FROM pages WHERE allocated=FALSE LIMIT 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No free pages available';
    END IF;

    virtual_addr := floor(random()*1000000)::BIGINT;
    UPDATE pages SET allocated=TRUE, allocated_to_thread=thread_id WHERE id=p.id;
    INSERT INTO page_tables (thread_id, page_id, virtual_address) VALUES (thread_id, p.id, virtual_addr);

    RETURN virtual_addr;
END;
$$ LANGUAGE plpgsql;
--------------
-- FILESYSTEM
--------------

-- filesystem
CREATE TABLE IF NOT EXISTS files (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id INTEGER REFERENCES files(id),  -- Directory structure
    owner_user_id INTEGER REFERENCES users(id),
    permissions TEXT NOT NULL,  -- e.g. 'rwxr-x---'
    contents TEXT DEFAULT '',
    is_directory BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT now(),
    group_id INTEGER REFERENCES groups(id)
);

-- File locks
CREATE TABLE IF NOT EXISTS file_locks (
    file_id INTEGER REFERENCES files(id),
    locked_by_user INTEGER REFERENCES users(id),
    lock_mode TEXT CHECK (lock_mode IN('read','write')),
    PRIMARY KEY(file_id, locked_by_user)
);

-- File versions for versioning
CREATE TABLE IF NOT EXISTS file_versions (
    id SERIAL PRIMARY KEY,
    file_id INTEGER REFERENCES files(id),
    version_number INTEGER,
    contents TEXT,
    created_at TIMESTAMP DEFAULT now()
);


-- Create a file or directory
CREATE OR REPLACE FUNCTION create_file(user_id INTEGER, filename TEXT, parent_id INTEGER, is_dir BOOLEAN DEFAULT FALSE) RETURNS INTEGER AS $$
DECLARE
    new_file_id INTEGER;
BEGIN
    IF NOT check_permission(user_id, 'file', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to create files', user_id;
    END IF;

    INSERT INTO files (name, parent_id, owner_user_id, permissions, is_directory)
    VALUES (filename, parent_id, user_id, 'rwxr-----', is_dir)
    RETURNING id INTO new_file_id;

    RETURN new_file_id;
END;
$$ LANGUAGE plpgsql;


-- Write to a file
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

    -- Check if user is owner and has write permission or user has role that grants write
    IF f.owner_user_id = user_id THEN
        -- Owner permissions are in first three chars (e.g., 'rwx')
        IF substring(f.permissions from 1 for 3) NOT LIKE '%w%' THEN
            RAISE EXCEPTION 'Owner does not have write permission on this file';
        END IF;
    ELSIF NOT check_permission(user_id, 'file', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to write files', user_id;
    END IF;

    UPDATE files SET contents = data WHERE id = file_id;
END;
$$ LANGUAGE plpgsql;


-- Read from a file
CREATE OR REPLACE FUNCTION read_file(user_id INTEGER, file_id INTEGER) RETURNS TEXT AS $$
DECLARE
    f RECORD;
    result TEXT;
BEGIN
    SELECT * INTO f FROM files WHERE id = file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    IF f.is_directory THEN
        RAISE EXCEPTION 'Cannot read from a directory, list directory instead';
    END IF;

    -- Check read permission for owner or user permission
    IF f.owner_user_id = user_id THEN
        IF substring(f.permissions from 1 for 3) NOT LIKE 'r%' THEN
            RAISE EXCEPTION 'Owner does not have read permission on this file';
        END IF;
    ELSIF NOT check_permission(user_id, 'file', 'read') THEN
        RAISE EXCEPTION 'User % does not have permission to read files', user_id;
    END IF;

    result := f.contents;
    RETURN result;
END;
$$ LANGUAGE plpgsql;


-- Change file permissions (owner only)
CREATE OR REPLACE FUNCTION change_file_permissions(user_id INTEGER, file_id INTEGER, new_perms TEXT) RETURNS VOID AS $$
DECLARE
    f RECORD;
BEGIN
    SELECT * INTO f FROM files WHERE id = file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    IF f.owner_user_id != user_id THEN
        RAISE EXCEPTION 'Only the owner can change file permissions';
    END IF;

    IF length(new_perms) != 9 THEN
        RAISE EXCEPTION 'Permissions string must be 9 characters (e.g. rwxr-xr--)';
    END IF;

    UPDATE files SET permissions = new_perms WHERE id = file_id;
END;
$$ LANGUAGE plpgsql;


-- Lock a file
CREATE OR REPLACE FUNCTION lock_file(user_id INTEGER, file_id INTEGER, mode TEXT) RETURNS VOID AS $$
DECLARE
    f RECORD;
BEGIN
    SELECT * INTO f FROM files WHERE id=file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    INSERT INTO file_locks (file_id, locked_by_user, lock_mode)
    VALUES (file_id, user_id, mode);
END;
$$ LANGUAGE plpgsql;


-- Unlock a file
CREATE OR REPLACE FUNCTION unlock_file(user_id INTEGER, file_id INTEGER) RETURNS VOID AS $$
BEGIN
    DELETE FROM file_locks WHERE file_id=file_id AND locked_by_user=user_id;
END;
$$ LANGUAGE plpgsql;


-- Save a version of a file before write
CREATE OR REPLACE FUNCTION version_file(file_id INTEGER) RETURNS VOID AS $$
DECLARE
    f RECORD;
    max_version INTEGER;
BEGIN
    SELECT * INTO f FROM files WHERE id=file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    SELECT COALESCE(MAX(version_number),0) INTO max_version FROM file_versions WHERE file_id=file_id;
    INSERT INTO file_versions (file_id, version_number, contents) VALUES (file_id, max_version+1, f.contents);
END;
$$ LANGUAGE plpgsql;
-------
-- IPC
-------

-- Channels: named IPC endpoints that multiple processes can write/read
CREATE TABLE IF NOT EXISTS channels (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- Messages in channels
CREATE TABLE IF NOT EXISTS channel_messages (
    id SERIAL PRIMARY KEY,
    channel_id INTEGER REFERENCES channels(id),
    sender_process_id INTEGER REFERENCES processes(id),
    message TEXT,
    timestamp TIMESTAMP DEFAULT now()
);

-- Mailbox
CREATE TABLE IF NOT EXISTS mailbox (
    id SERIAL PRIMARY KEY,
    recipient_user_id INTEGER REFERENCES users(id),
    sender_user_id INTEGER REFERENCES users(id),
    message TEXT,
    timestamp TIMESTAMP DEFAULT now()
);


-- Register a channel
CREATE OR REPLACE FUNCTION register_channel(user_id INTEGER, channel_name TEXT) RETURNS VOID AS $$
BEGIN
    IF NOT check_permission(user_id, 'resource', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to create channels', user_id;
    END IF;

    INSERT INTO channels (name) VALUES (channel_name);
END;
$$ LANGUAGE plpgsql;


-- Write to a channel
CREATE OR REPLACE FUNCTION write_channel(user_id INTEGER, channel_name TEXT, sender_process_id INTEGER, msg TEXT) RETURNS VOID AS $$
DECLARE
    ch RECORD;
BEGIN
    SELECT * INTO ch FROM channels WHERE name = channel_name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Channel not found';
    END IF;

    IF NOT check_permission(user_id, 'resource', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to write to channels', user_id;
    END IF;

    INSERT INTO channel_messages (channel_id, sender_process_id, message) 
    VALUES (ch.id, sender_process_id, msg);
END;
$$ LANGUAGE plpgsql;


-- Read from a channel (retrieve all new messages)
CREATE OR REPLACE FUNCTION read_channel(user_id INTEGER, channel_name TEXT) RETURNS SETOF TEXT AS $$
DECLARE
    ch RECORD;
BEGIN
    SELECT * INTO ch FROM channels WHERE name = channel_name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Channel not found';
    END IF;

    IF NOT check_permission(user_id, 'resource', 'read') THEN
        RAISE EXCEPTION 'User % does not have permission to read channels', user_id;
    END IF;

    RETURN QUERY SELECT message FROM channel_messages WHERE channel_id = ch.id ORDER BY timestamp;
END;
$$ LANGUAGE plpgsql;


-- Send mail
CREATE OR REPLACE FUNCTION send_mail(sender_user_id INTEGER, recipient_user_id INTEGER, msg TEXT) RETURNS VOID AS $$
BEGIN
    IF NOT check_permission(sender_user_id, 'file', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to send mail (simulate as file write permission)', sender_user_id;
    END IF;

    INSERT INTO mailbox (recipient_user_id, sender_user_id, message) VALUES (recipient_user_id, sender_user_id, msg);
END;
$$ LANGUAGE plpgsql;


-- Check mail
CREATE OR REPLACE FUNCTION check_mail(user_id INTEGER) RETURNS SETOF TEXT AS $$
BEGIN
    IF NOT check_permission(user_id, 'file', 'read') THEN
        RAISE EXCEPTION 'User % does not have permission to read mail', user_id;
    END IF;

    RETURN QUERY SELECT message FROM mailbox WHERE recipient_user_id = user_id ORDER BY timestamp;
END;
$$ LANGUAGE plpgsql;
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
$$ LANGUAGE plpgsql;




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
$$ LANGUAGE plpgsql;


-- On fault, record the fault and possibly rollback to a checkpoint
CREATE OR REPLACE FUNCTION handle_fault(process_id INTEGER, fault_type TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO faults (process_id, fault_type) VALUES (process_id, fault_type);
    -- Recovery logic would go here, like restoring from a checkpoint
END;
$$ LANGUAGE plpgsql;
----------------------
-- GARBAGE COLLECTION
----------------------

-- Helper function to free all memory for a terminated process
CREATE OR REPLACE FUNCTION free_all_memory_for_process(process_id INTEGER) RETURNS VOID AS $$
DECLARE
    seg_id INTEGER;
BEGIN
    FOR seg_id IN SELECT segment_id FROM process_memory WHERE process_id = process_id LOOP
        UPDATE memory_segments SET allocated = FALSE, allocated_to = NULL WHERE id = seg_id;
        DELETE FROM process_memory WHERE process_id = process_id AND segment_id = seg_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION cleanup_terminated_processes(timeout_interval INTERVAL DEFAULT '1 hour') RETURNS VOID AS $$
DECLARE
    old_procs RECORD;
BEGIN
    -- Find processes terminated for longer than timeout_interval
    FOR old_procs IN
        SELECT id FROM processes
        WHERE state = 'terminated'
          AND now() - updated_at > timeout_interval
    LOOP
        -- Free memory segments
        PERFORM free_all_memory_for_process(old_procs.id);

        -- Remove signals for this process
        DELETE FROM signals WHERE process_id = old_procs.id;

        -- Optionally, remove process-specific IPC messages if you store them that way

        -- In a real scenario, you might archive logs or process records here
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-------------------------
-- DEVICE AND I/O MANAGEMENT
-------------------------

CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    type TEXT CHECK (type IN ('disk','network','other')) NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS device_queue (
    id SERIAL PRIMARY KEY,
    device_id INTEGER REFERENCES devices(id),
    request_type TEXT CHECK (request_type IN('read','write')),
    data TEXT,
    completed BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP DEFAULT now()
);

CREATE OR REPLACE FUNCTION enqueue_io_request(device_name TEXT, request_type TEXT, data TEXT) RETURNS VOID AS $$
DECLARE
    dev RECORD;
BEGIN
    SELECT * INTO dev FROM devices WHERE name=device_name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Device % not found', device_name;
    END IF;

    INSERT INTO device_queue (device_id, request_type, data) VALUES (dev.id, request_type, data);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_device_queue(device_name TEXT) RETURNS VOID AS $$
DECLARE
    dev RECORD;
    req RECORD;
BEGIN
    SELECT * INTO dev FROM devices WHERE name=device_name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Device % not found', device_name;
    END IF;

    FOR req IN SELECT * FROM device_queue WHERE device_id=dev.id AND completed=FALSE ORDER BY timestamp LOOP
        -- Simulate processing
        PERFORM pg_sleep(0.05);
        UPDATE device_queue SET completed=TRUE WHERE id=req.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;-------------------------
-- NETWORKING
-------------------------


CREATE TABLE IF NOT EXISTS network_interfaces (
    id SERIAL PRIMARY KEY,
    interface_name TEXT UNIQUE NOT NULL,
    ip_address TEXT,
    created_at TIMESTAMP DEFAULT now()
);


CREATE TABLE IF NOT EXISTS sockets (
    id SERIAL PRIMARY KEY,
    interface_id INTEGER REFERENCES network_interfaces(id),
    port INTEGER,
    connected_to TEXT,
    created_at TIMESTAMP DEFAULT now()
);


-- Send packet simulation
CREATE OR REPLACE FUNCTION send_packet(socket_id INTEGER, data TEXT) RETURNS VOID AS $$
DECLARE
    s RECORD;
BEGIN
    SELECT * INTO s FROM sockets WHERE id=socket_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Socket % not found', socket_id;
    END IF;

    -- Just simulate logging the send
    RAISE NOTICE 'Sending packet from socket % to %: %', socket_id, s.connected_to, data;
END;
$$ LANGUAGE plpgsql;-----------
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
$$ LANGUAGE plpgsql;--------------------
-- POWER MANAGEMENT
--------------------

CREATE TABLE IF NOT EXISTS power_states (
    id SERIAL PRIMARY KEY,
    state TEXT CHECK(state IN('running','sleeping','suspended','hibernate')),
    timestamp TIMESTAMP DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_power_state(new_state TEXT) RETURNS VOID AS $$
BEGIN
    IF new_state NOT IN ('running','sleeping','suspended','hibernate') THEN
        RAISE EXCEPTION 'Invalid power state';
    END IF;
    INSERT INTO power_states (state) VALUES (new_state);
END;
$$ LANGUAGE plpgsql;
-- processes
CREATE INDEX IF NOT EXISTS idx_processes_state ON processes(state);
CREATE INDEX IF NOT EXISTS idx_processes_priority ON processes(priority);
CREATE INDEX IF NOT EXISTS idx_processes_owner ON processes(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_processes_updated_at ON processes(updated_at);
CREATE INDEX IF NOT EXISTS idx_process_logs_process ON process_logs(process_id);
CREATE INDEX IF NOT EXISTS idx_process_logs_timestamp ON process_logs(timestamp);

-- scheduler
CREATE INDEX IF NOT EXISTS idx_threads_state ON threads(state);
CREATE INDEX IF NOT EXISTS idx_threads_priority ON threads(priority);
CREATE INDEX IF NOT EXISTS idx_threads_process_id ON threads(process_id);

-- locks
CREATE INDEX IF NOT EXISTS idx_mutexes_name ON mutexes(name);
CREATE INDEX IF NOT EXISTS idx_semaphores_name ON semaphores(name);

-- signals
CREATE INDEX IF NOT EXISTS idx_signals_process ON signals(process_id);
CREATE INDEX IF NOT EXISTS idx_signals_timestamp ON signals(timestamp);

-- userrolespermissions
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_permissions_role ON permissions(role_id);

-- memory
CREATE INDEX IF NOT EXISTS idx_memory_segments_allocated ON memory_segments(allocated);
CREATE INDEX IF NOT EXISTS idx_memory_segments_process ON memory_segments(allocated_to);
CREATE INDEX IF NOT EXISTS idx_pages_allocated ON pages(allocated);
CREATE INDEX IF NOT EXISTS idx_page_tables_thread ON page_tables(thread_id);

-- fs
CREATE INDEX IF NOT EXISTS idx_files_name ON files(name);
CREATE INDEX IF NOT EXISTS idx_files_parent ON files(parent_id);
CREATE INDEX IF NOT EXISTS idx_file_locks_file ON file_locks(file_id);

-- ipc
CREATE INDEX IF NOT EXISTS idx_channels_name ON channels(name);
CREATE INDEX IF NOT EXISTS idx_channel_messages_channel ON channel_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_mailbox_recipient ON mailbox(recipient_user_id);

-- audit
CREATE INDEX IF NOT EXISTS idx_file_logs_file ON file_logs(file_id);
CREATE INDEX IF NOT EXISTS idx_memory_logs_process ON memory_logs(process_id);
CREATE INDEX IF NOT EXISTS idx_faults_process ON faults(process_id);

-- gc


-- io
CREATE INDEX IF NOT EXISTS idx_devices_name ON devices(name);
CREATE INDEX IF NOT EXISTS idx_device_queue_device ON device_queue(device_id);
CREATE INDEX IF NOT EXISTS idx_device_queue_completed ON device_queue(completed);

-- network
CREATE INDEX IF NOT EXISTS idx_network_interfaces_name ON network_interfaces(interface_name);
CREATE INDEX IF NOT EXISTS idx_sockets_interface ON sockets(interface_id);

-- modules
CREATE INDEX IF NOT EXISTS idx_modules_name ON modules(module_name);
CREATE INDEX IF NOT EXISTS idx_modules_loaded ON modules(loaded);

-- power
CREATE INDEX IF NOT EXISTS idx_power_states_state ON power_states(state);
CREATE INDEX IF NOT EXISTS idx_power_states_timestamp ON power_states(timestamp);
