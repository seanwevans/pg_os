-- tests for IPC channels and the user mailbox
\set ECHO none
SET client_min_messages TO warning;
DROP EXTENSION IF EXISTS pg_os CASCADE;
CREATE EXTENSION pg_os;
\set ECHO queries
\set VERBOSITY terse

-- setup: two users sharing a role with the relevant permissions
SELECT create_user('producer') AS prod \gset
SELECT create_user('consumer') AS cons \gset
SELECT create_role('ipc_role') AS rid \gset
SELECT assign_role_to_user(:prod, :rid);
SELECT assign_role_to_user(:cons, :rid);
SELECT grant_permission_to_role(:rid, 'resource', 'read');
SELECT grant_permission_to_role(:rid, 'resource', 'write');
SELECT grant_permission_to_role(:rid, 'file', 'read');
SELECT grant_permission_to_role(:rid, 'file', 'write');

-- channels: register, write, then drain
SELECT register_channel(:prod, 'chan1');
SELECT write_channel(:prod, 'chan1', NULL, 'ping');
SELECT read_channel(:cons, 'chan1');
-- reading a channel removes the delivered messages
SELECT count(*) AS messages_left FROM channel_messages;

-- mailbox: send then check
SELECT send_mail(:prod, :cons, 'hello consumer');
SELECT check_mail(:cons);

-- writing to a missing channel fails
\set ON_ERROR_STOP off
SELECT write_channel(:prod, 'nope', NULL, 'x');
\set ON_ERROR_STOP on
