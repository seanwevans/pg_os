----------------------
-- GARBAGE COLLECTION
----------------------

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
