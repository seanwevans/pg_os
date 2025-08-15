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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


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

    RETURN QUERY DELETE FROM channel_messages
        WHERE channel_id = ch.id
        ORDER BY timestamp
        RETURNING message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


-- Send mail
CREATE OR REPLACE FUNCTION send_mail(sender_user_id INTEGER, recipient_user_id INTEGER, msg TEXT) RETURNS VOID AS $$
BEGIN
    IF NOT check_permission(sender_user_id, 'file', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to send mail (simulate as file write permission)', sender_user_id;
    END IF;

    INSERT INTO mailbox (recipient_user_id, sender_user_id, message) VALUES (recipient_user_id, sender_user_id, msg);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;


-- Check mail
CREATE OR REPLACE FUNCTION check_mail(user_id INTEGER) RETURNS SETOF TEXT AS $$
BEGIN
    IF NOT check_permission(user_id, 'file', 'read') THEN
        RAISE EXCEPTION 'User % does not have permission to read mail', user_id;
    END IF;

    RETURN QUERY SELECT message FROM mailbox WHERE recipient_user_id = user_id ORDER BY timestamp;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
