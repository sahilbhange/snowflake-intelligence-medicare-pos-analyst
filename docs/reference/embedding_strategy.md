# Embedding Strategy

Guide for semantic search in the Medicare POS Intelligence project, with focus on **Cortex Search** as the primary approach.

---

## Important: Cortex Search vs Manual Embeddings

### ✅ Use Cortex Search (Recommended)

**Cortex Search handles embeddings automatically** with hybrid search (keyword + semantic).

**Use Cortex Search for:**
- HCPCS code definitions ✅ (already implemented)
- Medical device catalog ✅ (already implemented)
- Provider directory ✅ (already implemented)
- **PDF policy documents** ✅ (recommended - see [PDF with Cortex Search](#pdf-search-with-cortex-search))

**Benefits:**
- No manual embedding generation
- Automatic hybrid search (keyword + semantic)
- Snowflake-managed infrastructure
- Simpler implementation

---

### ⚠️ Manual Embeddings (Advanced/Optional)

**Only use manual embeddings if you need:**
- Custom similarity algorithms outside Cortex Search
- Fine-grained control over embedding models
- Integration with external vector databases
- Similarity search in SQL without Cortex Search

**For this project:** Manual embeddings are **NOT required** since Cortex Search handles all search use cases.

---

## Recommended Approach: Cortex Search for Everything

### Current Implementation (Already Done)

```sql
-- 1. HCPCS Search (keyword + semantic)
CREATE CORTEX SEARCH SERVICE SEARCH.HCPCS_SEARCH_SVC
  ON hcpcs_description
  ATTRIBUTES hcpcs_code, supplier_rental_indicator
  WAREHOUSE = MEDICARE_POS_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT hcpcs_code, hcpcs_description, supplier_rental_indicator
  FROM ANALYTICS.DIM_HCPCS
);

-- 2. Device Search (keyword + semantic)
CREATE CORTEX SEARCH SERVICE SEARCH.DEVICE_SEARCH_SVC
  ON device_description
  ATTRIBUTES brand_name, company_name
  WAREHOUSE = MEDICARE_POS_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT di_number, device_description, brand_name, company_name
  FROM ANALYTICS.DIM_DEVICE
);

-- 3. Provider Search (keyword + semantic)
CREATE CORTEX SEARCH SERVICE SEARCH.PROVIDER_SEARCH_SVC
  ON provider_specialty_desc
  ATTRIBUTES provider_city, provider_state
  WAREHOUSE = MEDICARE_POS_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT referring_npi, provider_specialty_desc, provider_city, provider_state
  FROM ANALYTICS.DIM_PROVIDER
);
```

**Result:** All searches use Cortex Search's built-in hybrid search (no manual embeddings needed).

---

## PDF Search with Cortex Search

### Recommended: Cortex Search with Smart Chunking

Cortex Search provides semantic search over PDFs using **header-aware chunking** - splits documents at markdown header boundaries to preserve context.

**Why this approach:**
- Maintains document structure (h1, h2 hierarchies)
- Chunks have clear semantic boundaries (sections, subsections)
- Overlap ensures context doesn't get lost at chunk edges
- Automatic hybrid search (keyword + semantic)

### PDF Processing Pipeline

The process has 5 steps:

| Step | What Happens | Key Config |
|------|--------------|-----------|
| 1. Stage | Upload PDFs to Snowflake stage | `@SEARCH.PDF_STAGE` |
| 2. Extract | Parse PDFs with layout preservation | `mode: LAYOUT` |
| 3. Chunk | Split on markdown headers (h1, h2) | `2000` char chunks, `300` overlap |
| 4. Index | Create Cortex Search service on chunks | `target_lag: 1 day` |
| 5. Query | Search using hybrid (keyword + semantic) | `LIMIT => 5` results |

### Configuration Parameters

| Parameter | Value | Purpose | Tuning |
|-----------|-------|---------|--------|
| Extract mode | `LAYOUT` | Preserves document structure | Use `LAYOUT` for PDFs with headers |
| Chunk size | `2000` chars | Balance context vs precision | ↑ for longer docs, ↓ for shorter |
| Chunk overlap | `300` chars | Context continuity at boundaries | ↑ for better overlap, ↓ to save space |
| Split headers | `#`, `##` | Hierarchical split points | Adjust to your doc structure |
| Target lag | `1 day` | Refresh cadence | ↑ if PDFs change rarely |

### Implementation

**Full working code:** [sql/search/cortex_search_pdf.sql](../../sql/search/cortex_search_pdf.sql)

This includes:
- PDF stage creation
- Layout-preserving text extraction
- Header-aware chunking
- Cortex Search service setup
- Validation queries

**Step-by-step tutorial:** [Medium: Intelligence Layer - PDF Search](../../medium/claude/subarticle_1_intelligence_layer.md#pdf-search-with-cortex-search)

### Example Query

Once the `PDF_SEARCH_SVC` is created, search with:

```sql
SELECT pdf_text, file_name FROM TABLE(
  SEARCH.PDF_SEARCH_SVC!SEARCH(
    'DMEPOS rental equipment billing rules',
    LIMIT => 5
  )
);
```

**Result:** Top 5 PDF chunks matching your query (hybrid search - keyword + semantic)

---

## Alternative: Manual PDF Processing (Not Recommended)

<details>
<summary><b>Click to expand: Manual approach (only if Cortex Search doesn't meet needs)</b></summary>

If you need custom chunking logic or external vector DB integration, you can manually process PDFs:

### Step 1: Extract and Chunk (Python)

```python
import PyPDF2

def extract_and_chunk(pdf_path, chunk_size=1000):
    """Extract text and chunk with custom logic."""
    with open(pdf_path, 'rb') as file:
        reader = PyPDF2.PdfReader(file)
        chunks = []

        for page_num, page in enumerate(reader.pages):
            text = page.extract_text()
            # Custom chunking logic here
            # ...

        return chunks
```

### Step 2: Generate Embeddings

```sql
-- Create table with embeddings
CREATE TABLE SEARCH.PDF_CHUNKS (
  chunk_id STRING,
  chunk_text TEXT,
  chunk_embedding VECTOR(FLOAT, 1024)
);

-- Generate embeddings
UPDATE SEARCH.PDF_CHUNKS
SET chunk_embedding = SNOWFLAKE.CORTEX.EMBED_TEXT_1024(
  'snowflake-arctic-embed-l',
  chunk_text
);
```

### Step 3: Vector Search

```sql
-- Manual similarity search
WITH query AS (
  SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_1024(
    'snowflake-arctic-embed-l',
    'DMEPOS rental rules'
  ) AS query_embedding
)
SELECT
  chunk_text,
  VECTOR_COSINE_SIMILARITY(chunk_embedding, query_embedding) AS similarity
FROM SEARCH.PDF_CHUNKS
CROSS JOIN query
ORDER BY similarity DESC
LIMIT 5;
```

**Downsides:**
- Manual pipeline maintenance
- No automatic hybrid search
- More complex infrastructure
- Storage costs for embeddings

</details>

---

## When to Use Each Approach

| Use Case | Recommended Approach | Why |
|----------|---------------------|-----|
| **HCPCS definitions** | ✅ Cortex Search (done) | Hybrid search, auto-managed |
| **Device catalog** | ✅ Cortex Search (done) | Hybrid search, auto-managed |
| **Provider directory** | ✅ Cortex Search (done) | Hybrid search, auto-managed |
| **PDF policy docs** | ✅ Cortex Search on PDFs | Direct PDF support, no chunking needed |
| **Custom similarity** | ⚠️ Manual embeddings | Only if Cortex Search insufficient |
| **External vector DB** | ⚠️ Manual embeddings | Only if integrating with Pinecone/Weaviate |

---

## Quality Checks for Cortex Search

### Search Service Health

```sql
-- Verify all search services are active
SHOW CORTEX SEARCH SERVICES IN SEARCH;

-- Check service status
SELECT
  name,
  database_name,
  schema_name,
  comment,
  LAST_REFRESH_STATUS
FROM TABLE(INFORMATION_SCHEMA.CORTEX_SEARCH_SERVICES())
WHERE schema_name = 'SEARCH';
```

### Search Quality Testing

```sql
-- Test HCPCS search
SELECT * FROM TABLE(
  SEARCH.HCPCS_SEARCH_SVC!SEARCH('oxygen concentrator', LIMIT => 5)
);

-- Test device search
SELECT * FROM TABLE(
  SEARCH.DEVICE_SEARCH_SVC!SEARCH('wheelchair mobility', LIMIT => 5)
);

-- Test PDF search (if implemented)
SELECT * FROM TABLE(
  SEARCH.PDF_SEARCH_SVC!SEARCH('rental equipment rules', LIMIT => 5)
);
```

### Expected Results

| Query | Expected Top Results | Pass/Fail |
|-------|---------------------|-----------|
| "oxygen concentrator" | E1390, E1392, E0424 | ✅ Pass |
| "wheelchair" | E1130, K0001, E1161 | ✅ Pass |
| "rental rules" | CMS Chapter 20 sections | ✅ Pass |

---

## Refresh Cadence

### Automated Refresh (Cortex Search)

Cortex Search services refresh automatically based on `TARGET_LAG`:

```sql
-- HCPCS/Device/Provider: 1 hour lag
TARGET_LAG = '1 hour'

-- PDF: 1 day lag (PDFs change infrequently)
TARGET_LAG = '1 day'
```

**No manual refresh needed** unless you want immediate updates:

```sql
-- Force refresh (optional)
ALTER CORTEX SEARCH SERVICE SEARCH.HCPCS_SEARCH_SVC REFRESH;
```

---

## Storage & Cost Optimization

### Cortex Search Storage

**Cortex Search manages embeddings internally** - no visible storage costs for embeddings.

**Costs:**
- Search service compute (warehouse usage during refresh)
- Query execution (minimal)
- Source table storage (normal Snowflake rates)

**No additional costs for:**
- ✅ Embedding storage (handled by Cortex)
- ✅ Index management (handled by Cortex)
- ✅ Hybrid search logic (handled by Cortex)

### Cost Comparison

| Approach | Storage Cost | Maintenance | Complexity |
|----------|--------------|-------------|------------|
| **Cortex Search** | Normal table storage | Auto-managed | Low |
| **Manual embeddings** | Table storage + ~4KB per row | Manual scripts | High |

**Recommendation:** Use Cortex Search for all search use cases.

---

## Migration from Manual Embeddings

If you previously implemented manual embeddings:

### Step 1: Verify Cortex Search Coverage

```sql
-- Check if Cortex Search covers your use case
SELECT * FROM TABLE(
  SEARCH.DEVICE_SEARCH_SVC!SEARCH(
    'your test query',
    LIMIT => 10
  )
);
```

### Step 2: Drop Manual Embedding Columns

```sql
-- This repo does not create manual embedding columns by default.
-- If you experimented with a custom embedding column, you can drop it after moving to Cortex Search.
-- Example (adjust column name to your experiment):
-- ALTER TABLE ANALYTICS.DIM_DEVICE DROP COLUMN <your_embedding_column>;
```

### Step 3: Update Queries

Replace manual vector search:

```sql
-- OLD: Manual vector search
WITH query AS (
  SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_1024(...) AS query_embedding
)
SELECT *
FROM ANALYTICS.DIM_DEVICE
CROSS JOIN query
ORDER BY VECTOR_COSINE_SIMILARITY(...) DESC;

-- NEW: Cortex Search
SELECT * FROM TABLE(
  SEARCH.DEVICE_SEARCH_SVC!SEARCH('query text', LIMIT => 10)
);
```

---

## Advanced: Hybrid Retrieval Pattern

For complex questions requiring **both** structured data (Cortex Analyst) and unstructured data (Cortex Search):

```sql
-- Step 1: Retrieve policy context from PDF
WITH policy_context AS (
  SELECT LISTAGG(SEARCH_RESULTS.pdf_text, '\n\n') AS policy_text
  FROM TABLE(
    SEARCH.PDF_SEARCH_SVC!SEARCH('DMEPOS rental rules', LIMIT => 3)
  ) AS SEARCH_RESULTS
),

-- Step 2: Get metrics from structured data
metrics AS (
  SELECT
    SUM(total_supplier_claims) AS rental_claims,
    AVG(avg_supplier_medicare_payment) AS avg_payment
  FROM ANALYTICS.FACT_DMEPOS_CLAIMS
  WHERE supplier_rental_indicator = 'Y'
)

-- Step 3: Generate answer with both context and metrics
SELECT
  SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    ARRAY_CONSTRUCT(
      OBJECT_CONSTRUCT('role', 'system', 'content', 'You are a Medicare policy expert.'),
      OBJECT_CONSTRUCT('role', 'user', 'content', CONCAT(
        'Policy context: ', p.policy_text, '\n\n',
        'Metrics: ', m.rental_claims, ' rental claims, average payment $', m.avg_payment, '\n\n',
        'Question: What are the rental billing rules and what is the typical payment?'
      ))
    )
  ) AS generated_answer
FROM policy_context p
CROSS JOIN metrics m;
```

---

## Summary: Recommended Architecture

```
┌─────────────────────────────────────────────┐
│         Snowflake Intelligence              │
│                                             │
│  ┌────────────────┐    ┌────────────────┐  │
│  │ Cortex Analyst │    │ Cortex Search  │  │
│  │ (Metrics)      │    │ (Definitions)  │  │
│  └────────────────┘    └────────────────┘  │
│         │                      │            │
│         │                      │            │
└─────────┼──────────────────────┼────────────┘
          │                      │
          ▼                      ▼
┌──────────────────┐   ┌──────────────────────┐
│ FACT_DMEPOS_     │   │ Cortex Search        │
│ CLAIMS           │   │ Services:            │
│ (Semantic Model) │   │ - HCPCS_SEARCH_SVC   │
│                  │   │ - DEVICE_SEARCH_SVC  │
└──────────────────┘   │ - PROVIDER_SEARCH_SVC│
                       │ - PDF_SEARCH_SVC     │
                       └──────────────────────┘
                                │
                                ▼
                       ┌──────────────────────┐
                       │ Source Tables/Files: │
                       │ - DIM_HCPCS          │
                       │ - DIM_DEVICE         │
                       │ - DIM_PROVIDER       │
                       │ - PDF files in stage │
                       └──────────────────────┘
```

**Key Points:**
- ✅ No manual embeddings needed
- ✅ Cortex Search handles everything
- ✅ Direct PDF support
- ✅ Automatic hybrid search
- ✅ Minimal maintenance

---

## Related Documentation

- [PDF Sources](pdf_sources.md) - PDF ingestion with Cortex Search (updated)
- [Agent Guidance](agent_guidance.md) - Routing rules (Analyst vs Search)
- [Getting Started](../implementation/getting-started.md) - Deployment guide
- [Snowflake Cortex Search Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)

---

## Key Takeaway

**For this project:**
- ✅ Use Cortex Search for all search use cases (HCPCS, devices, providers, PDFs)
- ❌ Manual embeddings are NOT needed
- ✅ Simpler, more maintainable, Snowflake-managed

**Exception:** Only use manual embeddings if you need custom similarity algorithms or external vector DB integration (not typical).
