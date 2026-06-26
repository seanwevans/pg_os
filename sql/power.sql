-- tests for set_power_state
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- a valid transition is recorded
SELECT set_power_state('suspended');
SELECT state FROM power_states ORDER BY id DESC LIMIT 1;

-- an unknown state is rejected
\set ON_ERROR_STOP off
SELECT set_power_state('banana');
\set ON_ERROR_STOP on

-- the rejected state was not recorded
SELECT count(*) AS recorded_states FROM power_states;
