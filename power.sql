--------------------
-- POWER MANAGEMENT
--------------------

CREATE TABLE IF NOT EXISTS power_states (
    id SERIAL PRIMARY KEY,
    state TEXT CHECK(state IN('running','sleeping','suspended','hibernate')),
    timestamp TIMESTAMP DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_power_state(new_state TEXT) RETURNS VOID AS $$
BEGIN
    IF new_state NOT IN ('running','sleeping','suspended','hibernate') THEN
        RAISE EXCEPTION 'Invalid power state';
    END IF;
    INSERT INTO power_states (state) VALUES (new_state);
END;
$$ LANGUAGE plpgsql;
