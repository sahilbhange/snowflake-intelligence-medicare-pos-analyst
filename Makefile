# Demo automation helpers for Snowflake Intelligence Medicare POS.
#
# Usage:
#   make demo            # Quick demo (data → setup → model → search → governance)
#   make deploy-all      # Full deployment (demo + validation + tests + agent)
#   make help            # Show all targets

SNOW ?= snow
SNOW_OPTS ?= sql -c sf_int
SNOW_CMD = $(SNOW) $(SNOW_OPTS)

.PHONY: data setup load model search pdf-setup search-pdf pdf-validate instrumentation metadata profile validation knowledge-graph tests agent grants \
        demo deploy-all verify rebuild-model rebuild-search clean-tests teardown help

# ============================================================================
# PHASE 1: DATA LAYER
# ============================================================================

# Download public source data locally.
data:
	@echo "📥 Downloading source data..."
	python data/dmepos_referring_provider_download.py --max-rows 1000000
	bash data/data_download.sh
	@echo "✅ Data download complete"

# ============================================================================
# PHASE 2: INFRASTRUCTURE
# ============================================================================

# Create roles, warehouse, database, and schemas.
setup:
	@echo "🏗️  Setting up Snowflake infrastructure..."
	$(SNOW_CMD) -f sql/setup/setup_user_and_roles.sql
	@echo "✅ Infrastructure setup complete"

# ============================================================================
# PHASE 3: DATA INGESTION & MODELING
# ============================================================================

# Load raw files into Snowflake (requires local data from 'make data' first).
load:
	@echo "📦 Loading raw data to Snowflake..."
	$(SNOW_CMD) -f sql/ingestion/load_raw_data.sql
	@echo "✅ Raw data loaded"

# Build curated tables and analytics views (medallion: CURATED → ANALYTICS).
model:
	@echo "🏗️  Building data model (CURATED → ANALYTICS)..."
	$(SNOW_CMD) -f sql/transform/build_curated_model.sql
	@echo "✅ Data model complete"

# ============================================================================
# PHASE 4: CORTEX SEARCH SERVICES
# ============================================================================

# Create Cortex Search services for HCPCS, devices, and providers.
search:
	@echo "🔍 Creating Cortex Search services..."
	$(SNOW_CMD) -f sql/search/cortex_search_hcpcs.sql
	$(SNOW_CMD) -f sql/search/cortex_search_devices.sql
	$(SNOW_CMD) -f sql/search/cortex_search_providers.sql
	@echo "✅ Search services created"

# Setup PDF stage and show upload instructions (run BEFORE search-pdf).
pdf-setup:
	@echo "📄 Setting up PDF stage..."
	$(SNOW_CMD) -f sql/setup/pdf_stage_setup.sql
	@echo "✅ PDF stage ready (upload PDFs, then run: make search-pdf)"

# Create Cortex Search service for PDFs (requires pdf-setup first).
search-pdf:
	@echo "🔍 Creating PDF search service..."
	$(SNOW_CMD) -f sql/search/cortex_search_pdf.sql
	@echo "✅ PDF search service created"

# Validate PDF search service works (run AFTER search-pdf).
pdf-validate:
	@echo "✔️  Validating PDF search..."
	$(SNOW_CMD) -f sql/setup/pdf_search_validation.sql
	@echo "✅ PDF search validated"

# ============================================================================
# PHASE 5: GOVERNANCE & INSTRUMENTATION
# ============================================================================

# Create data quality, metadata, and lineage infrastructure.
metadata:
	@echo "📊 Setting up metadata catalog..."
	$(SNOW_CMD) -f sql/governance/metadata_and_quality.sql
	@echo "✅ Metadata catalog created"

# Run data profiling (baseline row counts, null rates, distributions).
profile:
	@echo "📈 Running data profiling..."
	$(SNOW_CMD) -f sql/governance/run_profiling.sql
	@echo "✅ Data profiling complete (check GOVERNANCE.DATA_PROFILE_RESULTS)"

# Create query logging and evaluation seed tables.
instrumentation:
	@echo "🔧 Setting up instrumentation..."
	$(SNOW_CMD) -f sql/intelligence/instrumentation.sql
	$(SNOW_CMD) -f sql/intelligence/eval_seed.sql
	@echo "✅ Instrumentation tables created"

# Create knowledge graph entities and relationships.
knowledge-graph:
	@echo "🧠 Building knowledge graph..."
	$(SNOW_CMD) -f sql/intelligence/knowledge_graph.sql
	@echo "✅ Knowledge graph created"

# Create human validation framework (feedback, business questions, insights).
validation:
	@echo "✅ Setting up validation framework..."
	$(SNOW_CMD) -f sql/intelligence/validation_framework.sql
	@echo "✅ Validation framework created"

# ============================================================================
# PHASE 6: CORTEX AGENT (requires all search services + semantic model)
# ============================================================================

# Create Cortex Agent (multi-tool orchestrator).
# PREREQUISITE: Semantic model YAML must be uploaded to @ANALYTICS.CORTEX_SEM_MODEL_STG
# See: docs/reference/cortex_agent_creation.md for instructions
agent:
	@echo "🤖 Creating Cortex Agent..."
	@echo "   ⚠️  Make sure semantic model YAML is uploaded to @ANALYTICS.CORTEX_SEM_MODEL_STG"
	@echo "   📚 See: sql/agent/cortex_agent.sql for prerequisites"
	$(SNOW_CMD) -f sql/agent/cortex_agent.sql
	@echo "✅ Cortex Agent created"

# ============================================================================
# PHASE 7: TESTING & VALIDATION
# ============================================================================

# Run semantic model regression tests (should return all PASS).
tests:
	@echo "🧪 Running semantic model tests..."
	$(SNOW_CMD) -f sql/intelligence/semantic_model_tests.sql
	@echo "✅ Tests complete (check INTELLIGENCE.SEMANTIC_TEST_RESULTS)"

# ============================================================================
# PHASE 8: PERMISSIONS
# ============================================================================

# Apply final grants to all created objects.
grants:
	@echo "🔐 Applying grants..."
	$(SNOW_CMD) -f sql/setup/apply_grants.sql
	@echo "✅ Grants applied"

# ============================================================================
# ORCHESTRATED DEPLOYMENT CHAINS
# ============================================================================

# End-to-end demo setup (recommended starting point).
# Downloads data, creates infrastructure, builds model, creates search services,
# sets up governance, and applies grants.
demo: data setup load model search metadata profile instrumentation knowledge-graph grants
	@echo ""
	@echo "🎉 Demo deployment complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Verify data: SELECT COUNT(*) FROM ANALYTICS.FACT_DMEPOS_CLAIMS;"
	@echo "  2. Test search: SELECT * FROM SEARCH.HCPCS_SEARCH_SVC('oxygen');"
	@echo "  3. Run validation framework: make validation"
	@echo "  4. Create agent (if semantic model uploaded): make agent"
	@echo "  5. Run tests: make verify"

# Full production-ready deployment (includes validation + tests + agent).
# Includes everything in demo, plus validation framework, tests, and agent.
deploy-all: demo validation tests agent
	@echo ""
	@echo "✅ Full production deployment complete!"
	@echo ""
	@echo "What was deployed:"
	@echo "  ✅ Data ingestion (RAW → CURATED → ANALYTICS)"
	@echo "  ✅ Cortex Search services (HCPCS, Devices, Providers)"
	@echo "  ✅ Metadata & governance (column definitions, lineage, quality)"
	@echo "  ✅ Query instrumentation (logging, eval seeds)"
	@echo "  ✅ Knowledge graph (entities, relationships)"
	@echo "  ✅ Human validation framework (feedback collection)"
	@echo "  ✅ Semantic model tests (regression testing)"
	@echo "  ✅ Cortex Agent (multi-tool orchestrator)"
	@echo ""
	@echo "Verify deployment: make verify"

# ============================================================================
# DEVELOPMENT & MAINTENANCE
# ============================================================================

# Rebuild data model (drop and recreate CURATED/ANALYTICS layers).
# Use when you've modified the transform logic.
rebuild-model: model profile
	@echo "✅ Data model rebuilt"

# Rebuild search services (drop and recreate).
# Use when you've modified search corpus definitions.
rebuild-search: search
	@echo "✅ Search services rebuilt"

# Clean up test results (useful before re-running tests).
clean-tests:
	@echo "🧹 Cleaning test results..."
	$(SNOW_CMD) -q "TRUNCATE TABLE INTELLIGENCE.SEMANTIC_TEST_RESULTS;"
	@echo "✅ Test results cleared"

# ============================================================================
# CLEANUP & RESET
# ============================================================================

# Complete teardown: drop database, warehouse, roles, and all objects.
# WARNING: This will permanently delete everything. Use with caution!
teardown:
	@echo ""
	@echo "⚠️  WARNING: This will DELETE everything!"
	@echo "    - Database: MEDICARE_POS_DB"
	@echo "    - Warehouse: MEDICARE_POS_WH"
	@echo "    - Roles: MEDICARE_POS_ADMIN, MEDICARE_POS_INTELLIGENCE"
	@echo "    - All tables, views, search services, agents"
	@echo ""
	@read -p "Type 'yes' to confirm deletion: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(SNOW_CMD) -f sql/cleanup/teardown.sql && \
		echo "" && \
		echo "✅ Teardown complete!" && \
		echo "📝 To redeploy, run: make demo"; \
	else \
		echo "❌ Teardown cancelled."; \
	fi

# ============================================================================
# VERIFICATION
# ============================================================================

# Run tests and show results (quick deployment verification).
verify:
	@echo "🧪 Running deployment verification..."
	$(SNOW_CMD) -f sql/intelligence/semantic_model_tests.sql
	@echo "✅ Verification complete"
	@echo "📊 Check test results: SELECT * FROM INTELLIGENCE.SEMANTIC_TEST_RESULTS WHERE result = 'FAIL';"

# ============================================================================
# HELP & DOCUMENTATION
# ============================================================================

# Show help for available targets.
help:
	@echo ""
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║     Snowflake Intelligence Medicare POS - Makefile Targets     ║"
	@echo "╚════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📖 QUICK START:"
	@echo "  make demo              Fresh install (data + infrastructure + model)"
	@echo "  make deploy-all        Full production deployment (demo + validation + agent)"
	@echo ""
	@echo "📥 DATA LAYER:"
	@echo "  make data              Download CMS and FDA source data"
	@echo ""
	@echo "🏗️  INFRASTRUCTURE:"
	@echo "  make setup             Create roles, warehouse, database, schemas"
	@echo "  make grants            Apply permissions to all objects"
	@echo ""
	@echo "📦 DATA INGESTION & MODELING:"
	@echo "  make load              Load raw data (RAW schema)"
	@echo "  make model             Build curated/analytics views"
	@echo "  make rebuild-model     Rebuild model (drop and recreate)"
	@echo ""
	@echo "🔍 SEARCH & AI:"
	@echo "  make search            Create Cortex Search services (HCPCS, devices, providers)"
	@echo "  make pdf-setup         Set up PDF stage"
	@echo "  make search-pdf        Create PDF search service"
	@echo "  make pdf-validate      Test PDF search"
	@echo "  make rebuild-search    Rebuild all search services"
	@echo "  make agent             Create Cortex Agent (requires semantic model YAML uploaded)"
	@echo ""
	@echo "📊 GOVERNANCE & MONITORING:"
	@echo "  make metadata          Create metadata catalog and lineage"
	@echo "  make profile           Run data profiling (baseline)"
	@echo "  make instrumentation   Create query logging and eval seeds"
	@echo "  make knowledge-graph   Build knowledge graph entities"
	@echo ""
	@echo "✅ VALIDATION:"
	@echo "  make validation        Set up human validation framework"
	@echo "  make tests             Run semantic model regression tests"
	@echo "  make clean-tests       Clear test results"
	@echo "  make verify            Quick deployment verification"
	@echo ""
	@echo "💡 DEPLOYMENT CHAINS:"
	@echo "  demo                   Recommended first deployment"
	@echo "  deploy-all             Production-ready with all components"
	@echo ""
	@echo "🧹 CLEANUP & RESET:"
	@echo "  make teardown          Drop database + warehouse + roles (DELETES EVERYTHING)"
	@echo "                         Then run 'make demo' to redeploy from scratch"
	@echo ""
	@echo "📚 DOCUMENTATION:"
	@echo "  docs/implementation/getting-started.md       Step-by-step guide"
	@echo "  docs/implementation/data_model.md            Schema reference"
	@echo "  medium/claude/subarticle_*.md                Deep dives by layer"
	@echo ""
