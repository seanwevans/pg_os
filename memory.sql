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
        BEGIN
            PERFORM pg_advisory_lock(1);  -- simulate locking, ensure no other transaction interferes
            UPDATE memory_segments SET allocated = TRUE, allocated_to = process_id WHERE id = mem_seg.id;
            INSERT INTO process_memory (process_id, segment_id)
                VALUES (allocate_memory.process_id, mem_seg.id);
            PERFORM pg_advisory_unlock(1);
        EXCEPTION WHEN others THEN
            PERFORM pg_advisory_unlock(1);
            RAISE;
        END;

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

    DELETE FROM process_memory
        WHERE process_id = free_memory.process_id
          AND segment_id = free_memory.segment_id;
    UPDATE memory_segments
        SET allocated = FALSE, allocated_to = NULL
        WHERE id = free_memory.segment_id;
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
    INSERT INTO page_tables (thread_id, page_id, virtual_address)
        VALUES (allocate_page.thread_id, p.id, virtual_addr);

    RETURN virtual_addr;
END;
$$ LANGUAGE plpgsql;
