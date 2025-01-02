-----------
-- SIGNALS
-----------

-- signals
CREATE TABLE IF NOT EXISTS signals (
    id SERIAL PRIMARY KEY,
    process_id INTEGER NOT NULL REFERENCES processes(id),
    signal_type TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT now()
);


-- send a signal to a process
CREATE OR REPLACE FUNCTION send_signal(target_process_id INTEGER, signal_type TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO signals (process_id, signal_type) VALUES (target_process_id, signal_type);
    PERFORM log_process_action(target_process_id, 'Signal received: ' || signal_type);
END;
$$ LANGUAGE plpgsql;



-- handle signals before execution. This can be called at the start of execute_process, or periodically by the scheduler
CREATE OR REPLACE FUNCTION handle_signals(process_id INTEGER) RETURNS VOID AS $$
DECLARE
    sig RECORD;
BEGIN
    FOR sig IN SELECT * FROM signals WHERE process_id = process_id LOOP
        IF sig.signal_type = 'SIGTERM' THEN
            PERFORM terminate_process(process_id);
        ELSIF sig.signal_type = 'SIGSTOP' THEN
            UPDATE processes SET state = 'waiting', updated_at = now() WHERE id = process_id AND state != 'terminated';
            PERFORM log_process_action(process_id, 'Process paused by signal');
        ELSIF sig.signal_type = 'SIGCONT' THEN
            UPDATE processes SET state = 'ready', updated_at = now() WHERE id = process_id AND state = 'waiting';
            PERFORM log_process_action(process_id, 'Process continued by signal');
        END IF;

        -- Remove the processed signal
        DELETE FROM signals WHERE id = sig.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
