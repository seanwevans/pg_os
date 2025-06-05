-------------------------
-- NETWORKING
-------------------------


CREATE TABLE IF NOT EXISTS network_interfaces (
    id SERIAL PRIMARY KEY,
    interface_name TEXT UNIQUE NOT NULL,
    ip_address TEXT,
    created_at TIMESTAMP DEFAULT now()
);


CREATE TABLE IF NOT EXISTS sockets (
    id SERIAL PRIMARY KEY,
    interface_id INTEGER REFERENCES network_interfaces(id),
    port INTEGER,
    connected_to TEXT,
    created_at TIMESTAMP DEFAULT now()
);


-- Send packet simulation
CREATE OR REPLACE FUNCTION send_packet(socket_id INTEGER, data TEXT) RETURNS VOID AS $$
DECLARE
    s RECORD;
BEGIN
    SELECT * INTO s FROM sockets WHERE id=socket_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Socket % not found', socket_id;
    END IF;

    -- Just simulate logging the send
    RAISE NOTICE 'Sending packet from socket % to %: %', socket_id, s.connected_to, data;
END;
$$ LANGUAGE plpgsql;
