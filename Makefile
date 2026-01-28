# Demo automation helpers for Snowflake Intelligence Medicare POS.

SNOW ?= snow
SNOW_OPTS ?= sql -c sf_int
SNOW_CMD = $(SNOW) $(SNOW_OPTS)

.PHONY: data setup load model search instrumentation metadata profile validation tests grants knowledge-graph demo deploy-all verify help

# Download public source data locally.
data:
	python data/dmepos_referring_provider_download.py --max-rows 1000000
	bash data/data_download.sh

# Create roles, warehouse, database, and schema.
setup:
	$(SNOW_CMD) -f sql/setup/setup_user_and_roles.sql

# Load raw files into Snowflake after running PUT commands.
load:
	$(SNOW_CMD) -f sql/ingestion/load_raw_data.sql

# Build curated tables and views.
model:
	$(SNOW_CMD) -f sql/transform/build_curated_model.sql

# Create Cortex Search services.
search:
	$(SNOW_CMD) -f sql/search/cortex_search_hcpcs.sql
	$(SNOW_CMD) -f sql/search/cortex_search_devices.sql
	$(SNOW_CMD) -f sql/search/cortex_search_providers.sql

# Setup PDF stage and upload instructions (run BEFORE search-pdf).
pdf-setup:
	$(SNOW_CMD) -f sql/setup/pdf_stage_setup.sql

# Create Cortex Search service for PDF documents (requires pdf-setup first).
search-pdf:
	@echo "Note: Run 'make pdf-setup' and upload PDFs before running this."
	$(SNOW_CMD) -f sql/search/cortex_search_pdf.sql

# Validate PDF search service (run AFTER search-pdf).
pdf-validate:
	$(SNOW_CMD) -f sql/setup/pdf_search_validation.sql

# Create instrumentation tables and eval prompts.
instrumentation:
	$(SNOW_CMD) -f sql/intelligence/instrumentation.sql
	$(SNOW_CMD) -f sql/intelligence/eval_seed.sql

# Create metadata, lineage, and quality scaffolds.
metadata:
	$(SNOW_CMD) -f sql/governance/metadata_and_quality.sql

# Run profiling to capture row counts and null rates.
profile:
	$(SNOW_CMD) -f sql/governance/run_profiling.sql

# Create human validation framework (business questions, insights, feedback tables).
validation:
	$(SNOW_CMD) -f sql/intelligence/validation_framework.sql

# Create knowledge graph scaffolding tables.
knowledge-graph:
	$(SNOW_CMD) -f sql/intelligence/knowledge_graph.sql

# Run semantic model regression tests.
tests:
	$(SNOW_CMD) -f sql/intelligence/semantic_model_tests.sql

# Apply post-creation grants (Cortex Search services, views, etc.).
grants:
	$(SNOW_CMD) -f sql/setup/apply_grants.sql

# End-to-end demo setup (data download, SQL objects, search, instrumentation, metadata).
demo: data setup load model search instrumentation metadata grants

# Full deployment including validation framework and tests.
deploy-all: demo validation tests
	@echo "Full deployment complete. Run 'make verify' to check results."

# Verify deployment by running tests only.
verify:
	$(SNOW_CMD) -f sql/intelligence/semantic_model_tests.sql
	@echo "Check INTELLIGENCE.SEMANTIC_TEST_SUMMARY for results."

# Show help for available targets.
help:
	@echo "Available targets:"
	@echo "  data           - Download source data"
	@echo "  setup          - Create roles, warehouse, database, schemas"
	@echo "  load           - Load raw data into Snowflake (RAW schema)"
	@echo "  model          - Build curated tables and views (CURATED/ANALYTICS)"
	@echo "  search         - Create Cortex Search services (SEARCH schema)"
	@echo "  pdf-setup      - Create PDF stage and show upload instructions"
	@echo "  search-pdf     - Create PDF search service (requires pdf-setup first)"
	@echo "  pdf-validate   - Validate and test PDF search service"
	@echo "  instrumentation - Create logging and eval tables (INTELLIGENCE)"
	@echo "  metadata       - Create metadata and lineage tables (GOVERNANCE)"
	@echo "  profile        - Run profiling and store results (GOVERNANCE)"
	@echo "  validation     - Create human validation framework (INTELLIGENCE)"
	@echo "  knowledge-graph - Create KG entities and relationships (INTELLIGENCE)"
	@echo "  tests          - Run semantic model tests"
	@echo "  grants         - Apply post-creation grants (Cortex Search, views)"
	@echo "  demo           - Full demo setup (recommended for fresh install)"
	@echo "  deploy-all     - Full deployment with validation"
	@echo "  verify         - Run tests to verify deployment"
