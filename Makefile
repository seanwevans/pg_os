EXTENSION = pg_os
DATA = pg_os--1.0.sql
PG_CONFIG ?= pg_config
REGRESS = pg_os_basic create_user lock_file create_process allocate_memory load_unload_module modules check_permission free_all_memory_for_process
REGRESS_OPTS = --outputdir=/tmp/pg_os_regress
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
