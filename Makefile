# Demo automation helpers for Snowflake Intelligence Medicare POS.

SNOWSQL ?= snowsql
SNOWSQL_OPTS ?=
SNOWSQL_CMD = $(SNOWSQL) $(SNOWSQL_OPTS)

.PHONY: data setup load model search instrumentation demo

# Download public source data locally.
data:
	python data/dmepos_referring_provider_download.py --max-rows 1000000
	bash data/data_download.sh

# Create roles, warehouse, database, and schema.
setup:
	$(SNOWSQL_CMD) -f scripts/step_1_user_setup.sql

# Load raw files into Snowflake after running PUT commands.
load:
	$(SNOWSQL_CMD) -f scripts/step_3_data_load.sql

# Build curated tables and views.
model:
	$(SNOWSQL_CMD) -f scripts/step_4_data_model.sql

# Create Cortex Search services.
search:
	$(SNOWSQL_CMD) -f models/cortex_search_hcpcs.sql
	$(SNOWSQL_CMD) -f models/cortex_search_devices.sql
	$(SNOWSQL_CMD) -f models/cortex_search_providers.sql

# Create instrumentation tables and eval prompts.
instrumentation:
	$(SNOWSQL_CMD) -f models/instrumentation.sql
	$(SNOWSQL_CMD) -f models/eval_seed.sql

# End-to-end demo setup (data download, SQL objects, search, instrumentation).
demo: data setup load model search instrumentation
