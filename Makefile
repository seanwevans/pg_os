EXTENSION = pg_os
DATA = pg_os--1.0.sql
PG_CONFIG ?= pg_config
REGRESS = pg_os_basic create_user lock_file create_process

# Write regression test output to a temporary directory under /tmp so that
# running `make installcheck` as an unprivileged PostgreSQL user does not
# require write access to the extension source tree.
REGRESS_OPTS = --outputdir=/tmp/pg_os_regress
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
