-- test for free_all_memory_for_process
\set ECHO none
SET client_min_messages TO warning;

-- minimal tables
DROP TABLE IF EXISTS memory_segments CASCADE;
DROP TABLE IF EXISTS process_memory CASCADE;
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

-- function under test
CREATE OR REPLACE FUNCTION free_all_memory_for_process(process_id INTEGER) RETURNS VOID AS $$
DECLARE
    seg_id INTEGER;
BEGIN
    FOR seg_id IN
        SELECT segment_id
          FROM process_memory
         WHERE process_memory.process_id = free_all_memory_for_process.process_id
    LOOP
        UPDATE memory_segments
           SET allocated = FALSE,
               allocated_to = NULL
         WHERE id = seg_id;
        DELETE FROM process_memory
         WHERE process_memory.process_id = free_all_memory_for_process.process_id
           AND segment_id = seg_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- allocate memory to processes 1 and 2
INSERT INTO memory_segments(size, allocated, allocated_to) VALUES
    (100, TRUE, 1),
    (100, TRUE, 1),
    (100, TRUE, 2);

INSERT INTO process_memory(process_id, segment_id) VALUES
    (1, 1),
    (1, 2),
    (2, 3);

\set ECHO queries
\set VERBOSITY terse

-- free all memory for process 1
SELECT free_all_memory_for_process(1);

-- inspect results
SELECT id, allocated, allocated_to FROM memory_segments ORDER BY id;
SELECT process_id, segment_id FROM process_memory ORDER BY process_id, segment_id;
