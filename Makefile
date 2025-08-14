EXTENSION = pg_os
DATA = pg_os--1.0.sql
PG_CONFIG ?= pg_config
REGRESS = pg_os_basic create_user lock_file create_process modules
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
