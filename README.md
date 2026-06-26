# pg_os
<img width="256" alt="Tables everywhere" src="https://github.com/user-attachments/assets/4cfe1575-ebc5-4727-8f10-64e6a99cb48b" />


## Overview
`pg_os` is a PostgreSQL extension that models operating-system concepts entirely
inside the database. Tables stand in for kernel objects (processes, threads,
memory segments, files, mutexes, semaphores, devices, …) and PL/pgSQL functions
play the role of system calls that operate on them under a small permission
model.

It is a teaching/experimentation toy rather than a way to control the host OS:
everything happens in SQL, so you can poke at schedulers, page allocation, file
permissions, IPC and locking without leaving `psql`.

## Features
- **Users, roles & permissions** – a minimal RBAC layer that gates the other subsystems.
- **Process management** – create, start, execute, prioritise and terminate simulated processes.
- **Scheduler** – priority / round-robin / SJF process scheduling and a simple thread scheduler.
- **Memory management** – allocate and free memory segments, and allocate paged virtual addresses per thread.
- **Filesystem** – a hierarchical file table with permissions, locking and content versioning.
- **IPC** – named channels and a per-user mailbox.
- **Locks** – mutexes and counting semaphores exposed through `SECURITY DEFINER` helpers.
- **Signals** – send and handle `SIGTERM` / `SIGSTOP` / `SIGCONT`.
- **Garbage collection** – free memory for terminated processes and reap stale ones.
- **Devices & I/O, networking, modules, power** – small simulated subsystems for completeness.

## Requirements
- PostgreSQL 12 or newer
- `plpgsql` (bundled with PostgreSQL; declared as a dependency)
- The PGXS build headers (`postgresql-server-dev-*`) to build and install

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/seanwevans/pg_os.git
   cd pg_os
   ```
2. Build and install with PGXS:
   ```bash
   make
   sudo make install
   ```
   To build against a specific PostgreSQL install, point `PG_CONFIG` at it:
   ```bash
   make PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
   ```
3. Create the extension in your database. You may install it into a dedicated
   schema if you prefer:
   ```sql
   CREATE EXTENSION pg_os;                       -- into the current schema
   -- or
   CREATE EXTENSION pg_os WITH SCHEMA os;        -- into schema "os"
   ```
   Creating the extension also ensures a `pgos_admin` role exists; it owns the
   `SECURITY DEFINER` locking helpers (see [Security model](#security-model)).

## Usage
The functions are intentionally small. A typical session looks like this:

```sql
CREATE EXTENSION pg_os;

-- 1. Set up a user, a role, and grant it some permissions
SELECT create_user('alice')              AS alice_id;   -- => 1
SELECT create_role('operator')           AS role_id;    -- => 1
SELECT assign_role_to_user(1, 1);
SELECT grant_permission_to_role(1, 'process', 'execute');
SELECT grant_permission_to_role(1, 'memory',  'allocate');
SELECT grant_permission_to_role(1, 'file',    'write');

-- 2. Create and inspect a process (create_process is a PROCEDURE)
CALL create_process('worker', 1, 5);        -- name, owner_id, priority
SELECT name, state, priority FROM processes;

-- 3. Allocate memory to the process
INSERT INTO memory_segments (size) VALUES (4096);
SELECT allocate_memory(1, 1, 1024);         -- user_id, process_id, size
SELECT process_id, segment_id FROM process_memory;

-- 4. Create, write and read a file (with automatic versioning)
SELECT create_file(1, 'notes.txt', NULL, FALSE) AS file_id;   -- => 1
SELECT write_file(1, 1, 'hello');
SELECT write_file(1, 1, 'hello world');
SELECT read_file(1, 1);                                       -- => 'hello world'
SELECT version_number, contents FROM file_versions WHERE file_id = 1 ORDER BY version_number;

-- 5. Concurrency primitives (callable by unprivileged roles, see below)
SELECT create_semaphore('jobs', 1, 1);
SELECT acquire_semaphore(1, 'jobs');
SELECT release_semaphore(1, 'jobs');
```

Permissions are enforced with `check_permission(user_id, resource_type, action)`,
where `resource_type` is one of `process`, `file`, `resource`, `memory` and
`action` is one of `read`, `write`, `execute`, `allocate`, `delete`. Calls that
require a permission the user lacks raise an exception.

### Selected functions by subsystem
| Subsystem | Functions |
|-----------|-----------|
| Users/roles | `create_user`, `create_role`, `assign_role_to_user`, `grant_permission_to_role`, `check_permission` |
| Processes | `create_process`, `start_process`, `execute_process`, `terminate_process`, `set_process_priority`, `pause_all_processes`, `resume_all_waiting_processes`, `list_processes_by_state`, `process_count_by_state` |
| Scheduler | `schedule_processes`, `schedule_threads` |
| Memory | `allocate_memory`, `free_memory`, `allocate_page`, `free_all_memory_for_process` |
| Filesystem | `create_file`, `read_file`, `write_file`, `change_file_permissions`, `lock_file`, `unlock_file`, `version_file` |
| IPC | `register_channel`, `write_channel`, `read_channel`, `send_mail`, `check_mail` |
| Locks | `create_mutex`, `lock_mutex`, `unlock_mutex`, `create_semaphore`, `acquire_semaphore`, `release_semaphore` |
| Signals | `send_signal`, `handle_signals` |
| GC | `cleanup_terminated_processes`, `free_all_memory_for_process` |
| I/O / Net / Modules / Power | `enqueue_io_request`, `process_device_queue`, `send_packet`, `load_module`, `unload_module`, `set_power_state` |

## Security model
Most functions run with the privileges of the caller. The mutex and semaphore
helpers (`create_mutex`, `lock_mutex`, `unlock_mutex`, `create_semaphore`,
`acquire_semaphore`, `release_semaphore`) are `SECURITY DEFINER` and owned by the
`pgos_admin` role, with `EXECUTE` granted to `PUBLIC`. This lets an otherwise
unprivileged role manipulate locks and semaphores through the controlled API
without being granted direct access to the underlying tables. Their
`search_path` is pinned to the extension's schema (`@extschema@`) plus `pg_temp`
to avoid search-path injection.

## Testing
The extension ships a PGXS regression suite under `sql/` (inputs) and
`expected/` (expected output). With a running PostgreSQL cluster and a superuser
role for your OS user:

```bash
make
sudo make install
make installcheck
```

`make installcheck` creates a throwaway `contrib_regression` database, installs
the extension and runs every test listed in `REGRESS` in the `Makefile`. The same
flow runs on every push/PR via the GitHub Actions workflow in
`.github/workflows/test.yml`.

## Project layout
- `pg_os--1.0.sql` – the extension install script (tables, functions, indexes). Single source of truth.
- `pg_os.control` – extension control file.
- `Makefile` – PGXS build/test configuration.
- `sql/` – regression test inputs (plus `fs_constraints_migration.sql`, a one-off migration that tightens the `files` constraints on older installs).
- `expected/` – expected regression output.

## Contributing
Contributions are welcome. Please keep `pg_os--1.0.sql` and the regression tests
in sync: add or update a test under `sql/` and its `expected/` output for any
behavioural change, and make sure `make installcheck` passes before opening a
pull request.
