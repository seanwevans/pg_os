-- tests for semaphore wait/wake behaviour across processes
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup: two processes contending for a binary semaphore
SELECT create_user('sem_user') AS uid \gset
INSERT INTO processes (name, state, owner_user_id)
VALUES ('sem_p1', 'running', :uid)
RETURNING id AS p1 \gset
INSERT INTO processes (name, state, owner_user_id)
VALUES ('sem_p2', 'running', :uid)
RETURNING id AS p2 \gset
SELECT create_semaphore('sem', 1, 1);

-- first process acquires the only permit, dropping the count to zero
SELECT acquire_semaphore(:p1, 'sem');
SELECT count FROM semaphores WHERE name = 'sem';

-- second process finds none available and is parked as waiting
SELECT acquire_semaphore(:p2, 'sem');
SELECT state, waiting_on_semaphore FROM processes WHERE id = :p2;

-- releasing the permit wakes the oldest waiter
SELECT release_semaphore(:p1, 'sem');
SELECT state, waiting_on_semaphore FROM processes WHERE id = :p2;
SELECT count FROM semaphores WHERE name = 'sem';
