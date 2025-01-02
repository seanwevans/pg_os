\i processes.sql
\i scheduler.sql
\i locks.sql
\i signals.sql
\i userrolespermissions.sql
\i memory.sql
\i fs.sql
\i ipc.sql
\i audit.sql
\i gc.sql
\i io.sql
\i network.sql
\i modules.sql
\i power.sql

-- processes
CREATE INDEX IF NOT EXISTS idx_processes_state ON processes(state);
CREATE INDEX IF NOT EXISTS idx_processes_priority ON processes(priority);
CREATE INDEX IF NOT EXISTS idx_processes_owner ON processes(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_processes_updated_at ON processes(updated_at);
CREATE INDEX IF NOT EXISTS idx_process_logs_process ON process_logs(process_id);
CREATE INDEX IF NOT EXISTS idx_process_logs_timestamp ON process_logs(timestamp);

-- scheduler
CREATE INDEX IF NOT EXISTS idx_threads_state ON threads(state);
CREATE INDEX IF NOT EXISTS idx_threads_priority ON threads(priority);
CREATE INDEX IF NOT EXISTS idx_threads_process_id ON threads(process_id);

-- locks
CREATE INDEX IF NOT EXISTS idx_mutexes_name ON mutexes(name);
CREATE INDEX IF NOT EXISTS idx_semaphores_name ON semaphores(name);

-- signals
CREATE INDEX IF NOT EXISTS idx_signals_process ON signals(process_id);
CREATE INDEX IF NOT EXISTS idx_signals_timestamp ON signals(timestamp);

-- userrolespermissions
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_permissions_role ON permissions(role_id);

-- memory
CREATE INDEX IF NOT EXISTS idx_memory_segments_allocated ON memory_segments(allocated);
CREATE INDEX IF NOT EXISTS idx_memory_segments_process ON memory_segments(allocated_to);
CREATE INDEX IF NOT EXISTS idx_pages_allocated ON pages(allocated);
CREATE INDEX IF NOT EXISTS idx_page_tables_thread ON page_tables(thread_id);

-- fs
CREATE INDEX IF NOT EXISTS idx_files_name ON files(name);
CREATE INDEX IF NOT EXISTS idx_files_parent ON files(parent_id);
CREATE INDEX IF NOT EXISTS idx_file_locks_file ON file_locks(file_id);

-- ipc
CREATE INDEX IF NOT EXISTS idx_channels_name ON channels(name);
CREATE INDEX IF NOT EXISTS idx_channel_messages_channel ON channel_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_mailbox_recipient ON mailbox(recipient_user_id);

-- audit
CREATE INDEX IF NOT EXISTS idx_file_logs_file ON file_logs(file_id);
CREATE INDEX IF NOT EXISTS idx_memory_logs_process ON memory_logs(process_id);
CREATE INDEX IF NOT EXISTS idx_faults_process ON faults(process_id);

-- gc


-- io
CREATE INDEX IF NOT EXISTS idx_devices_name ON devices(name);
CREATE INDEX IF NOT EXISTS idx_device_queue_device ON device_queue(device_id);
CREATE INDEX IF NOT EXISTS idx_device_queue_completed ON device_queue(completed);

-- network
CREATE INDEX IF NOT EXISTS idx_network_interfaces_name ON network_interfaces(interface_name);
CREATE INDEX IF NOT EXISTS idx_sockets_interface ON sockets(interface_id);

-- modules
CREATE INDEX IF NOT EXISTS idx_modules_name ON modules(module_name);
CREATE INDEX IF NOT EXISTS idx_modules_loaded ON modules(loaded);

-- power
CREATE INDEX IF NOT EXISTS idx_power_states_state ON power_states(state);
CREATE INDEX IF NOT EXISTS idx_power_states_timestamp ON power_states(timestamp);
