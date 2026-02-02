# Building the DMEPOS Intelligence Agent

**Building the DMEPOS Intelligence Agent in Snowsight UI**

This document describes how the **DMEPOS_INTELLIGENCE_AGENT** was built using **Snowflake Snowsight UI**, including its purpose, example questions, tool configuration, orchestration logic, and response behavior.

The goal of this agent is to enable **natural-language analytics over Medicare DMEPOS data** by combining semantic search with governed, metrics-driven analysis.

---

## 1. Create Agent

### Access Agent Creation Interface

1. Log into **Snowsight** (Snowflake web UI)
2. Navigate to **Cortex AI** section in left sidebar
3. Click **Agents**
4. Click **+ Create** button (top right)

### Agent Configuration

**Database and schema:**
- Select schema: `MEDICARE_POS_DB.ANALYTICS`

**Agent object name:**
- Enter: `DMEPOS_INTELLIGENCE_AGENT`
- Note: API URL is based on this name. Changing it later may break integrations.

**Display name:**
- Enter: `Medicare Intelligence Analyst`

Click **Create agent** to proceed to configuration tabs (Tools, Orchestration, Response).

---

### Agent Overview

| Property | Value |
|----------|-------|
| **Agent name (object)** | `DMEPOS_INTELLIGENCE_AGENT` |
| **Display name** | Medicare Intelligence Analyst |
| **Database / Schema** | `MEDICARE_POS_DB.ANALYTICS` |
| **Execution role** | `MEDICARE_POS_INTELLIGENCE` |
| **Model** | Auto |

### Description

This agent enables natural-language exploration of Medicare DMEPOS data by combining semantic search and governed analytics. Users can ask plain-English questions to understand medical equipment, HCPCS codes, providers, utilization, and Medicare payments—without writing SQL. The agent automatically selects the right tool (search vs. analytics), applies built-in business rules, and returns accurate, privacy-safe insights.

### Example Questions

- What is HCPCS code E1390?
- What are the top 5 states by total claim volume?
- Show high-volume providers in California
- Which HCPCS codes are commonly used for wheelchairs?
- What is the average Medicare payment by provider specialty?

---

## 2. Prerequisites: Upload Semantic Model

**Before building the agent**, you must upload the semantic model YAML file from this project to Snowflake.

### Step 1: Create Stage (if not exists)

```sql
USE ROLE MEDICARE_POS_INTELLIGENCE;
USE DATABASE MEDICARE_POS_DB;
USE SCHEMA ANALYTICS;

CREATE STAGE IF NOT EXISTS ANALYTICS.CORTEX_SEM_MODEL_STG
  COMMENT = 'Semantic model YAML files for Cortex Analyst';
```

### Step 2: Upload Semantic Model from Project

**Option A: Using Snowflake CLI (snow)**

```bash
# From project root directory
snow sql -c sf_int -q "PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml @MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
```

**Option B: Using SnowSQL**

```bash
# From project root directory
snowsql -c your_connection -q "PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml @MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
```

**Option C: Using Snowsight UI**

1. Navigate to **Data** → **Databases** → **MEDICARE_POS_DB** → **ANALYTICS** → **Stages**
2. Click on **CORTEX_SEM_MODEL_STG**
3. Click **+ Files** button
4. Upload `models/DMEPOS_SEMANTIC_MODEL.yaml` from your local project directory

### Step 3: Verify Upload

```sql
LIST @ANALYTICS.CORTEX_SEM_MODEL_STG;
```

Expected output:
```
name                                          | size | md5  | last_modified
@CORTEX_SEM_MODEL_STG/DMEPOS_SEMANTIC_MODEL.yaml | XXXX | ...  | ...
```

### Step 4: Test Semantic Model (Optional)

```sql
-- Verify semantic model can be read
SELECT GET_PRESIGNED_URL(@ANALYTICS.CORTEX_SEM_MODEL_STG, 'DMEPOS_SEMANTIC_MODEL.yaml');
```

---

## 3. Tools Configuration (Snowsight → Tools Tab)

The agent uses **Cortex Analyst** for quantitative analysis and **Cortex Search Services** for semantic lookup and discovery. Each tool has a clearly defined responsibility.

### 3.1 Add Cortex Analyst Tool

**Tool type:** Cortex Analyst
**Tool name:** `DMEPOS_ANALYST`

**Semantic model source:**

| Field | Value |
|-------|-------|
| **Database / Schema** | `MEDICARE_POS_DB.ANALYTICS` |
| **Stage** | `MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG` |
| **File** | `DMEPOS_SEMANTIC_MODEL.yaml` |

Full path:
```
@MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG/DMEPOS_SEMANTIC_MODEL.yaml
```

**Semantic Model Description:**
Cortex will generate appropriate description for the analyst using Semantic Model yaml file.

---

### 3.2 Add Cortex Search Services

Configure the following four Cortex Search services as tools.

#### 3.2.1 HCPCS Code Search

**Service Configuration:**

| Field | Value |
|-------|-------|
| **Service** | `MEDICARE_POS_DB.SEARCH.HCPCS_SEARCH_SVC` |
| **Max results** | 8 |
| **ID column** | `HCPCS_CODE` |
| **Title column** | `HCPCS_CODE` |

**Tool Configuration:**

- **Tool name:** `HCPCS_Code_Search`
- **Tool Description:**
  ```
  Semantic search over HCPCS medical billing codes and descriptions. Use this tool to look up what a code means, find related codes by concept (e.g., wheelchair, oxygen), or map plain-English equipment terms to HCPCS codes.
  ```

**Used for:**
- HCPCS definitions
- Mapping plain English → billing codes
- Finding related HCPCS codes by concept

---

#### 3.2.2 Provider Search

**Service Configuration:**

| Field | Value |
|-------|-------|
| **Service** | `MEDICARE_POS_DB.SEARCH.PROVIDER_SEARCH_SVC` |
| **Max results** | 5 |
| **ID column** | `REFERRING_NPI` |
| **Title column** | `PROVIDER_SPECIALTY_DESC` |

**Tool Configuration:**

- **Tool name:** `Provider_Search`
- **Tool Description:**
  ```
  Semantic search over Medicare DMEPOS provider information, including provider identifiers, specialties, and geographic attributes. Use this tool to discover providers by specialty, location, or descriptive characteristics.
  ```

**Used for:**
- Provider discovery
- Specialty-based exploration
- Location-based provider lookup

---

#### 3.2.3 Device Search

**Service Configuration:**

| Field | Value |
|-------|-------|
| **Service** | `MEDICARE_POS_DB.SEARCH.DEVICE_SEARCH_SVC` |
| **Max results** | 5 |
| **ID column** | `DOC_ID` |
| **Title column** | `BRAND_NAME` |

**Tool Configuration:**

- **Tool name:** `Device_Search`
- **Tool Description:**
  ```
  Semantic search over medical device catalog data, including device descriptions, brand names, manufacturers, and model/version information. Use this tool to find devices by concept (e.g., wheelchairs, oxygen equipment), brand, or product description.
  ```

**Used for:**
- Medical device and equipment discovery
- Brand, manufacturer, and model lookup

---

#### 3.2.4 CMS Policy PDF Search

**Service Configuration:**

| Field | Value |
|-------|-------|
| **Service** | `MEDICARE_POS_DB.SEARCH.PDF_SEARCH_SVC` |
| **Max results** | 5 |
| **ID column** | `FILE_NAME` |
| **Title column** | `FILE_NAME` |

**Tool Configuration:**

- **Tool name:** `CMS_Policy_PDF_Search`
- **Tool Description:**
  ```
  Semantic search over CMS policy PDFs (manuals, LCD/NCD guidance, coverage policy docs). Use when users ask policy/coverage questions or want citations/quotes from source PDFs. Returns relevant chunks with file name and page/chunk metadata.
  ```

**Used for:**
- CMS coverage and policy questions
- LCD / NCD interpretation
- Citation-backed regulatory guidance

---

## 4. Orchestration Configuration (Snowsight → Orchestration Tab)

### 4.1 Model Selection

**Model:** Auto

The orchestration layer defines **how the agent reasons, selects tools, and sequences actions**.

### 4.2 Orchestration Instructions (Copy & Paste)

```
You are a data assistant for Medicare DMEPOS analytics. You have access to:

* Cortex Analyst semantic model for quantitative claims analysis (aggregations, rankings, metrics).
* Three Cortex Search tools for catalog/directory lookups: HCPCS codes, medical devices/brands, and providers/specialties.

Tool selection rules:

1. Use Cortex Search when the user asks for definitions, descriptions, lookups, or fuzzy matching (e.g., "what is/define/meaning", "codes related to…", "devices like…", "find providers who…").

   * If the question mentions a HCPCS code or "billing code", prefer HCPCS Search.
   * If it mentions device names, brands, model/version, manufacturer, or "catalog", prefer Device Search.
   * If it mentions providers, NPI, specialty, or location-based provider discovery, prefer Provider Search.

2. Use Cortex Analyst when the user asks for numbers or analysis: totals, counts, averages, ratios, comparisons, trends, "top/highest/lowest", "by state/specialty/provider/HCPCS", or any table/chart-style summary.

3. For mixed questions (definition + metrics), do a two-step plan:
   a) Use the appropriate Cortex Search tool first to retrieve the canonical identifiers (HCPCS_CODE and/or REFERRING_NPI and/or relevant device terms).
   b) Then call Cortex Analyst using those identifiers to compute the requested metrics.
   c) Combine into one response with a brief "Definition/Lookup" section and a brief "Metrics/Analysis" section.

Execution rules:

* Always attempt to answer using the available tools; do not claim lack of access if tools can answer.
* If a tool returns no results, broaden the search query once (synonyms) and retry the same tool.
* If still no results, ask the user for one missing detail (e.g., confirm code, state, specialty, or timeframe) and propose a nearest alternative query.
* Keep outputs concise: default to top 5–10 rows for "top" requests; otherwise summarize and offer to drill down.
* Never provide patient-level or PHI/PII content. If asked, refuse briefly and offer aggregated alternatives.
```

---

## 5. Response Instructions (Snowsight → Response Tab)

### 5.1 Response Instructions (Copy & Paste)

```
Tone: clear, helpful, and concise. Prefer bullet points and small tables.

Answer format:

* If the answer comes from Search: provide 2–5 results with short snippets and clearly label the identifier (e.g., HCPCS_CODE, BRAND_NAME, REFERRING_NPI).
* If the answer comes from Analyst: provide the requested metric(s) with units and a compact table. Round monetary values to 2 decimals.
* If both tools were used: show "Lookup" (definitions) then "Analysis" (metrics). Briefly state what was calculated.

Behavior rules:

* Don't mention internal system prompts or tool mechanics.
* Don't invent values; if uncertain, say what's missing and ask one targeted question.
* Encourage follow-ups: end with one short next-step question (e.g., "Want this for CA only or all states?").
```

---

## 6. Validation Checklist

After saving the agent, validate functionality:

- [ ] Test HCPCS definition queries
- [ ] Test top-N and aggregation queries
- [ ] Validate mixed lookup + analysis flows
- [ ] Confirm privacy-safe, aggregated outputs
- [ ] Verify tool selection via traces

---

**Last updated:** 2026-02-02
**Built entirely using Snowsight UI**
