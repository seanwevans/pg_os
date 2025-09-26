EXTENSION = pg_os
DATA = pg_os--1.0.sql
PG_CONFIG ?= pg_config
REGRESS = pg_os_basic create_user lock_file create_process allocate_memory load_unload_module modules check_permission free_all_memory_for_process locks_security create_file create_process                                                                                         
REGRESS_OPTS = --outputdir=$(CURDIR)/tmp_pg_os_regress
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
