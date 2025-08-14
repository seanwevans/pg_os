-------------------------
-- DEVICE AND I/O MANAGEMENT
-------------------------

CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    type TEXT CHECK (type IN ('disk','network','other')) NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS device_queue (
    id SERIAL PRIMARY KEY,
    device_id INTEGER REFERENCES devices(id),
    request_type TEXT CHECK (request_type IN('read','write')),
    data TEXT,
    completed BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP DEFAULT now()
);

CREATE OR REPLACE FUNCTION enqueue_io_request(device_name TEXT, request_type TEXT, data TEXT) RETURNS VOID AS $$
DECLARE
    dev RECORD;
BEGIN
    SELECT * INTO dev FROM devices WHERE name=device_name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Device % not found', device_name;
    END IF;

    INSERT INTO device_queue (device_id, request_type, data) VALUES (dev.id, request_type, data);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION enqueue_io_request(TEXT, TEXT, TEXT) OWNER TO pg_os_admin;

CREATE OR REPLACE FUNCTION process_device_queue(device_name TEXT) RETURNS VOID AS $$
DECLARE
    dev RECORD;
    req RECORD;
BEGIN
    SELECT * INTO dev FROM devices WHERE name=device_name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Device % not found', device_name;
    END IF;

    FOR req IN SELECT * FROM device_queue WHERE device_id=dev.id AND completed=FALSE ORDER BY timestamp LOOP
        -- Simulate processing
        PERFORM pg_sleep(0.05);
        UPDATE device_queue SET completed=TRUE WHERE id=req.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp;
ALTER FUNCTION process_device_queue(TEXT) OWNER TO pg_os_admin;
