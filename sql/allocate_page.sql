-- regression tests for allocate_page
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;

-- prepare memory pages and a thread that will allocate them
INSERT INTO pages (size)
SELECT 4096 FROM generate_series(1, 20);

SELECT create_user('allocator') AS user_id \gset
INSERT INTO processes (name, state, owner_user_id)
VALUES ('alloc_proc', 'new', :user_id)
RETURNING id AS process_id \gset
INSERT INTO threads (process_id, name)
VALUES (:process_id, 'alloc_thread')
RETURNING id AS thread_id \gset

\set ECHO queries
\set VERBOSITY terse

-- allocate a batch of pages for the same thread
SELECT allocate_page(:thread_id) FROM generate_series(1, 10);

-- verify the virtual addresses were allocated monotonically
SELECT virtual_address
  FROM page_tables
 WHERE thread_id = :thread_id
 ORDER BY virtual_address;
