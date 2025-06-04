# pg_os

## Overview
`pg_os` is a PostgreSQL extension that provides operating system-level functionality directly within the database environment. By leveraging SQL procedures and functions, `pg_os` enables users to interact with system processes, manage memory, handle inter-process communication (IPC), schedule tasks, and enforce security policies at the OS level.

The extension bridges the gap between the database and the underlying OS, allowing administrators to gain deep insights into system performance and control resource usage efficiently.

## Features
- **Process Management** – Monitor and control OS-level processes directly from PostgreSQL.
- **File System Operations** – Interact with the file system to read, write, and manipulate files.
- **Memory Management** – Analyze and manage memory allocations.
- **IPC (Inter-Process Communication)** – Facilitate communication between processes.
- **Scheduler** – Schedule jobs and tasks within PostgreSQL.
- **Locks** – Manage and analyze system and database locks.
- **Security** – Handle user roles and permissions at the OS level.
- **Network Monitoring** – Monitor and manage network interfaces and traffic.
- **Power Management** – Access and control power states of the system.
- **I/O Operations** – Track and manage input/output processes.
- **Signal Management** – Send and receive system signals.
- **Garbage Collection** – Monitor and optimize system garbage collection processes.
- **Module Management** – Inspect and control system modules.

## Requirements
- PostgreSQL 12+
- PL/pgSQL language extension enabled
- Sufficient OS-level permissions for system interaction

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/pg_os.git
   ```
2. Build and install the extension using PGXS:
   ```bash
   cd pg_os
   make
   sudo make install
   ```
3. Connect to your PostgreSQL instance:
   ```bash
   psql -U postgres -d your_database
   ```
4. Install the extension:
   ```sql
   CREATE EXTENSION pg_os;
   ```

## Usage
### 1. Process Management
```sql
SELECT * FROM os_processes();
```
- Lists all current OS processes and their statuses.

### 2. File System Operations
```sql
SELECT * FROM fs_list('/var/log');
```
- Retrieves the contents of a directory.

### 3. Memory Management
```sql
SELECT * FROM os_memory_usage();
```
- Displays memory consumption statistics.

### 4. IPC (Inter-Process Communication)
```sql
SELECT ipc_signal(12345, 'SIGTERM');
```
- Sends a termination signal to the process with PID 12345.

### 5. Locks
```sql
SELECT * FROM os_locks();
```
- Lists all current locks on system resources.

### 6. Scheduler
```sql
SELECT * FROM os_schedule_job('backup', '0 3 * * *', 'pg_dump your_database > backup.sql');
```
- Schedules a nightly backup at 3 AM.

### 7. Network Monitoring
```sql
SELECT * FROM os_network_interfaces();
```
- Lists all network interfaces and their statuses.

### 8. Power Management
```sql
SELECT os_power_state('suspend');
```
- Suspends the system.

### 9. I/O Operations
```sql
SELECT * FROM os_io_stats();
```
- Displays current I/O statistics.

### 10. Signal Management
```sql
SELECT os_send_signal(12345, 'SIGHUP');
```
- Sends a hang-up signal to the process with PID 12345.

### 11. Garbage Collection
```sql
SELECT * FROM os_gc_status();
```
- Monitors garbage collection processes.

### 12. Module Management
```sql
SELECT * FROM os_modules();
```
- Lists all loaded system modules.

### 13. Users, Roles, and Permissions
```sql
SELECT * FROM os_users_roles_permissions();
```
- Displays user roles and permissions.

## Source Files
- `audit.sql` – Handles audit logging and tracking.
- `fs.sql` – Implements file system operations.
- `ipc.sql` – Facilitates inter-process communication.
- `locks.sql` – Manages lock operations.
- `memory.sql` – Provides memory management utilities.
- `os.sql` – Core OS interaction functions.
- `processes.sql` – Monitors and manages system processes.
- `scheduler.sql` – Implements job scheduling.
- `usersrolespermissions.sql` – Manages users, roles, and permissions.
- `network.sql` – Handles network monitoring and management.
- `power.sql` – Implements power management functions.
- `io.sql` – Tracks I/O operations.
- `signals.sql` – Manages system signals.
- `gc.sql` – Monitors and controls garbage collection.
- `modules.sql` – Manages system modules.
- `pg_os--1.0.sql` – Extension script combining all modules.
- `pg_os.control` – Extension control file.

## Contributing
Contributions are welcome! Please open an issue or submit a pull request with any improvements or bug fixes.

## License
MIT License. See `LICENSE` for more details.

