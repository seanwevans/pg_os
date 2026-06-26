EXTENSION = pg_os
DATA = pg_os--1.0.sql
PG_CONFIG ?= pg_config
REGRESS = pg_os_basic \
          create_user \
          check_permission \
          create_process \
          allocate_memory \
          allocate_page \
          free_all_memory_for_process \
          create_file \
          file_versioning \
          lock_file \
          load_unload_module \
          modules \
          locks_security \
          semaphore_validation
REGRESS_OPTS = --outputdir=$(CURDIR)/tmp_pg_os_regress
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
