-- test for free_all_memory_for_process
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;

-- allocate memory to processes 1 and 2
INSERT INTO users (username) VALUES ('u1'), ('u2');
INSERT INTO processes (name, state, owner_user_id) VALUES ('p1','running',1), ('p2','running',2);
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
