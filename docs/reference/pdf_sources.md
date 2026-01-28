# PDF Sources

CMS policy documents for RAG (Retrieval-Augmented Generation) using **Cortex Search** (recommended approach).

---

## Overview

This guide covers PDF-based policy Q&A using **Cortex Search's built-in PDF support** - the simplest and most maintainable approach.

**Key benefit:** No manual text extraction, chunking, or embedding generation needed!

---

## Source Documents

| Doc ID | Source Name | URL | Pages | Last Updated |
|--------|-------------|-----|-------|--------------|
| CMS-001 | Medicare Claims Processing Manual, Chapter 20 (DMEPOS) | [CMS Downloads](https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c20.pdf) | ~150 | Quarterly |
| CMS-002 | Medicare Claims Processing Manual, Chapter 23 (Fee Schedule Admin) | [CMS Downloads](https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c23.pdf) | ~120 | Quarterly |

---

## Recommended: Cortex Search PDF Workflow

### Step 1: Download PDFs

```bash
# Create local docs folder
mkdir -p docs/cms_manuals

# Download CMS manuals
curl -o docs/cms_manuals/clm104c20_dmepos.pdf \
  "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c20.pdf"

curl -o docs/cms_manuals/clm104c23_fee_schedule.pdf \
  "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c23.pdf"
```

---

### Step 2: Upload to Snowflake Stage

```sql
-- Create stage for PDF files
CREATE STAGE IF NOT EXISTS SEARCH.PDF_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'CMS policy documents for RAG';

-- Upload PDFs using SnowSQL
-- (Or use Snowsight UI: Data > Stages > PDF_STAGE > Upload)
PUT file://docs/cms_manuals/*.pdf @SEARCH.PDF_STAGE AUTO_COMPRESS=FALSE;

-- Verify uploads
LIST @SEARCH.PDF_STAGE;
```

**Expected output:**
```
clm104c20_dmepos.pdf          5.2 MB    2024-01-26
clm104c23_fee_schedule.pdf    4.8 MB    2024-01-26
```

---

### Step 3: Create Cortex Search Service on PDFs

```sql
-- Create search service with PDF parsing
CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.PDF_SEARCH_SVC
  ON pdf_text
  ATTRIBUTES file_name, page_number
  WAREHOUSE = MEDICARE_POS_WH
  TARGET_LAG = '1 day'
  COMMENT = 'CMS policy manual search with automatic PDF parsing'
AS (
  SELECT
    RELATIVE_PATH AS file_name,
    -- Cortex automatically extracts and chunks PDF text
    SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
      @SEARCH.PDF_STAGE,
      RELATIVE_PATH,
      {'mode': 'LAYOUT'}  -- Preserves layout for better context
    ):content::STRING AS pdf_text,
    METADATA$FILE_ROW_NUMBER AS page_number,
    METADATA$FILE_LAST_MODIFIED AS last_modified
  FROM @SEARCH.PDF_STAGE
  WHERE RELATIVE_PATH LIKE '%.pdf'
);
```

**That's it!** Cortex Search handles:
- ✅ PDF text extraction
- ✅ Intelligent chunking
- ✅ Embedding generation
- ✅ Hybrid search (keyword + semantic)
- ✅ Index management

---

### Step 4: Query PDF Content

#### Basic Search

```sql
-- Search for rental equipment policy
SELECT
  file_name,
  page_number,
  pdf_text
FROM TABLE(
  SEARCH.PDF_SEARCH_SVC!SEARCH(
    'DMEPOS rental equipment billing rules',
    LIMIT => 5
  )
);
```

#### Advanced: RAG with Cortex Complete

```sql
-- Retrieve context and generate answer
WITH policy_context AS (
  SELECT LISTAGG(pdf_text, '\n\n---\n\n') AS context_text
  FROM TABLE(
    SEARCH.PDF_SEARCH_SVC!SEARCH(
      'rental equipment documentation requirements',
      LIMIT => 3
    )
  )
)
SELECT
  SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    ARRAY_CONSTRUCT(
      OBJECT_CONSTRUCT(
        'role', 'system',
        'content', 'You are a CMS policy expert. Answer based on provided policy context.'
      ),
      OBJECT_CONSTRUCT(
        'role', 'user',
        'content', CONCAT(
          'Policy Context:\n',
          context_text,
          '\n\nQuestion: What documentation is required for DMEPOS rental billing?'
        )
      )
    )
  ) AS answer
FROM policy_context;
```

---

## Quality Checks

### PDF Upload Verification

```sql
-- Check all PDFs are uploaded
SELECT
  RELATIVE_PATH AS file_name,
  SIZE AS file_size_bytes,
  ROUND(SIZE / 1024 / 1024, 2) AS file_size_mb,
  LAST_MODIFIED
FROM DIRECTORY(@SEARCH.PDF_STAGE);
```

**Expected:** 2 PDFs, ~5-10 MB total

---

### Search Service Health

```sql
-- Verify search service is active
SHOW CORTEX SEARCH SERVICES IN SEARCH;

-- Check last refresh status
SELECT
  name,
  database_name,
  schema_name,
  created_on,
  comment
FROM TABLE(INFORMATION_SCHEMA.CORTEX_SEARCH_SERVICES())
WHERE name = 'PDF_SEARCH_SVC';
```

---

### Search Quality Testing

```sql
-- Test retrieval quality with known queries
SELECT
  'Test 1: Rental rules' AS test_case,
  file_name,
  page_number,
  LEFT(pdf_text, 200) AS preview
FROM TABLE(
  SEARCH.PDF_SEARCH_SVC!SEARCH('rental equipment rules', LIMIT => 3)
)

UNION ALL

SELECT
  'Test 2: Fee schedule',
  file_name,
  page_number,
  LEFT(pdf_text, 200)
FROM TABLE(
  SEARCH.PDF_SEARCH_SVC!SEARCH('Medicare fee schedule calculation', LIMIT => 3)
)

UNION ALL

SELECT
  'Test 3: Documentation',
  file_name,
  page_number,
  LEFT(pdf_text, 200)
FROM TABLE(
  SEARCH.PDF_SEARCH_SVC!SEARCH('required documentation DMEPOS', LIMIT => 3)
);
```

**Expected results:**
- Test 1 should return Chapter 20 sections
- Test 2 should return Chapter 23 sections
- Test 3 should return documentation requirements

---

## Example Questions (Use Cases)

| Question Type | Example Query | Expected Source |
|---------------|---------------|-----------------|
| **Policy rules** | "What are CMS rules for DMEPOS rentals?" | Chapter 20, Section 20.3 |
| **Fee schedule** | "How is the Medicare fee schedule calculated?" | Chapter 23, Section 23.1 |
| **Documentation** | "What documentation is required for DME claims?" | Chapter 20, Section 20.5 |
| **Pricing** | "What are pricing exceptions for DMEPOS?" | Chapter 23, Section 23.4 |
| **Billing codes** | "How are rental vs purchase claims coded?" | Chapter 20, Rental section |

---

## Refresh Process

### When to Refresh

**CMS updates manuals quarterly.** Check for updates:
- CMS website announcements
- Subscribe to CMS mailing list
- Quarterly review schedule

### Refresh Steps

```sql
-- 1. Download updated PDFs (bash)
curl -o docs/cms_manuals/clm104c20_dmepos_v2.pdf \
  "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c20.pdf"

-- 2. Upload to stage (SnowSQL)
PUT file://docs/cms_manuals/clm104c20_dmepos_v2.pdf @SEARCH.PDF_STAGE OVERWRITE=TRUE;

-- 3. Cortex Search auto-refreshes based on TARGET_LAG
-- Or force refresh immediately:
ALTER CORTEX SEARCH SERVICE SEARCH.PDF_SEARCH_SVC REFRESH;

-- 4. Verify new content
SELECT file_name, last_modified
FROM DIRECTORY(@SEARCH.PDF_STAGE)
ORDER BY last_modified DESC;
```

**Note:** Cortex Search automatically detects updated files and re-indexes.

---

## Cost & Storage Estimates

### Storage

**PDF files:** ~5-10 MB total (negligible)
**Cortex Search index:** Managed by Snowflake (no visible storage cost)

### Compute

| Activity | Warehouse | Duration | Cost (approx) |
|----------|-----------|----------|---------------|
| Initial index creation | X-Small | ~5 min | ~$0.05 |
| Quarterly refresh | X-Small | ~5 min | ~$0.05 |
| Query execution | X-Small | <1 sec | <$0.01 |

**Total annual cost:** <$1 (negligible)

---

## Integration with Snowflake Intelligence

### Add PDF Search to Intelligence UI

1. Open Snowsight → AI & ML → Snowflake Intelligence
2. Click **Add Source** → **Cortex Search Service**
3. Configure:
   - Database: MEDICARE_POS_DB
   - Schema: SEARCH
   - Service: PDF_SEARCH_SVC
   - Display Name: "CMS Policy Documents"
   - Description: "Medicare DMEPOS policy manuals and fee schedule guidance"

4. Test query: "What are the rental billing rules?"

**Result:** Snowflake Intelligence automatically routes policy questions to PDF search.

---

## Advanced: Hybrid Query Pattern

Combine PDF policy context with structured metrics:

```sql
-- Step 1: Retrieve policy context
WITH policy_context AS (
  SELECT LISTAGG(pdf_text, '\n\n') AS policy_text
  FROM TABLE(
    SEARCH.PDF_SEARCH_SVC!SEARCH('DMEPOS rental rules', LIMIT => 3)
  )
),

-- Step 2: Get current metrics
rental_metrics AS (
  SELECT
    COUNT(DISTINCT referring_npi) AS providers,
    SUM(total_supplier_claims) AS total_claims,
    AVG(avg_supplier_medicare_payment) AS avg_payment
  FROM ANALYTICS.FACT_DMEPOS_CLAIMS
  WHERE supplier_rental_indicator = 'Y'
)

-- Step 3: Generate comprehensive answer
SELECT
  SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large2',
    ARRAY_CONSTRUCT(
      OBJECT_CONSTRUCT('role', 'system', 'content', 'You are a Medicare policy expert.'),
      OBJECT_CONSTRUCT('role', 'user', 'content', CONCAT(
        'CMS Policy:\n', p.policy_text, '\n\n',
        'Current Metrics:\n',
        '- Providers: ', m.providers, '\n',
        '- Claims: ', m.total_claims, '\n',
        '- Avg Payment: $', ROUND(m.avg_payment, 2), '\n\n',
        'Question: What are the rental billing rules and what is typical payment?'
      ))
    )
  ) AS comprehensive_answer
FROM policy_context p
CROSS JOIN rental_metrics m;
```

---

## Troubleshooting

### Issue: PDF Not Indexed

**Symptoms:** Search returns no results

**Solution:**
```sql
-- Check if PDF is in stage
LIST @SEARCH.PDF_STAGE;

-- Check if PARSE_DOCUMENT works
SELECT
  RELATIVE_PATH,
  SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
    @SEARCH.PDF_STAGE,
    RELATIVE_PATH,
    {'mode': 'LAYOUT'}
  ):content::STRING AS extracted_text
FROM @SEARCH.PDF_STAGE
WHERE RELATIVE_PATH = 'clm104c20_dmepos.pdf';

-- Force refresh
ALTER CORTEX SEARCH SERVICE SEARCH.PDF_SEARCH_SVC REFRESH;
```

---

### Issue: Poor Search Quality

**Symptoms:** Irrelevant results

**Solution:**
1. **Try different query phrasing:**
   ```sql
   -- Instead of: "rental"
   -- Try: "rental equipment billing" (more specific)
   ```

2. **Increase result limit:**
   ```sql
   SELECT * FROM TABLE(
     SEARCH.PDF_SEARCH_SVC!SEARCH('rental rules', LIMIT => 10)  -- More results
   );
   ```

3. **Check if PDF content is medical/relevant:**
   ```sql
   -- Sample PDF content to verify correct upload
   SELECT pdf_text
   FROM TABLE(SEARCH.PDF_SEARCH_SVC!SEARCH('DMEPOS', LIMIT => 1));
   ```

---

### Issue: PARSE_DOCUMENT Fails

**Symptoms:** Error during service creation

**Possible causes:**
- Corrupted PDF
- Encrypted/password-protected PDF
- Unsupported PDF format

**Solution:**
```bash
# Verify PDF is not corrupted
file docs/cms_manuals/clm104c20_dmepos.pdf

# Should output: "PDF document, version 1.x"

# If corrupted, re-download
curl -o docs/cms_manuals/clm104c20_dmepos.pdf \
  "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c20.pdf"
```

---

## Alternative: Manual Approach (Not Recommended)

<details>
<summary><b>Click to expand: Manual PDF processing (only if Cortex Search doesn't meet needs)</b></summary>

If you need custom chunking logic or external vector DB integration, see the manual approach in [Embedding Strategy](embedding_strategy.md#alternative-manual-pdf-processing-not-recommended).

**Downsides of manual approach:**
- Requires Python PDF extraction
- Manual chunking logic
- Manual embedding generation
- More complex pipeline
- Higher maintenance overhead

**Use only if:** You need fine-grained control over chunking or are integrating with external systems.

</details>

---

## Related Documentation

- [Embedding Strategy](embedding_strategy.md) - Cortex Search overview and manual fallback
- [Agent Guidance](agent_guidance.md) - When to use Search vs Analyst
- [Getting Started](../implementation/getting-started.md) - Deployment guide
- [Snowflake Cortex Search PDF Tutorial](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/tutorials/cortex-search-tutorial-3-chat-advanced)

---

## Summary: Recommended Workflow

```
┌─────────────────────────────────────────┐
│ 1. Download CMS PDFs (curl)             │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 2. Upload to Snowflake Stage (PUT)      │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 3. Create Cortex Search Service         │
│    - Automatic PDF parsing               │
│    - Automatic chunking                  │
│    - Automatic embedding                 │
│    - Automatic hybrid search             │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 4. Query via Snowflake Intelligence     │
│    - Policy questions auto-routed        │
│    - Hybrid retrieval (policy + metrics) │
└─────────────────────────────────────────┘
```

**Key takeaway:**
- ✅ Use Cortex Search PDF support (simplest)
- ❌ Manual PDF processing NOT needed
- ✅ 3-step setup: Download → Upload → Create Service
- ✅ Fully managed, auto-refreshing
