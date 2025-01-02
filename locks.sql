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


