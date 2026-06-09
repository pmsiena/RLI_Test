-- =============================================================================
-- RLI Insurance — Senior Data Engineer — Take-Home — Automation Concept
-- =============================================================================
-- Purpose: Demonstrates three ingestion patterns of increasing sophistication.
--          This file illustrates how the manual load process used in this 
--			exercise would be automated and evolved in a production environment.
--
-- Pattern 1: Truncate/Insert   — simple full reload, used in this project
-- Pattern 2: Append Only       — incremental inserts via COPY INTO + Streams
-- Pattern 3: Upsert via MERGE  — production-grade, only processes changed rows
--
-- In practice, I would start with Pattern 1 for speed, validate the
-- pipeline, then graduate to Pattern 3 as data volumes and SLA requirements grow.
-- =============================================================================


-- =============================================================================
-- PATTERN 1: TRUNCATE / INSERT
-- =============================================================================
-- Simplest approach. On each run, the table is cleared and fully reloaded.
-- Appropriate when:
--   - Dataset is small enough that full reloads are cheap
--   - Source system provides a full file extract on each run
--   - History preservation is not required
--
-- Downside: Loses row-level history. _insrt_ts reflects the last load, not
-- the original insert. Causes brief unavailability during truncate window.
-- =============================================================================

-- Step 1: Clear existing data
TRUNCATE TABLE RLI_TEST.RAW.POLICIES;

-- Step 2: Reload from stage
COPY INTO RLI_TEST.RAW.POLICIES
    (POLICY_ID, CUSTOMER_ID, POLICY_TYPE, EFFECTIVE_DATE, EXPIRATION_DATE, PREMIUM)
FROM @RLI_TEST.RAW.raw_stage/policies.csv
FILE_FORMAT = (
    TYPE                         = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER                  = 1
);

-- Repeat for all five tables:
-- TRUNCATE TABLE RLI_TEST.RAW.CUSTOMERS;   COPY INTO ...
-- TRUNCATE TABLE RLI_TEST.RAW.CLAIMS;      COPY INTO ...
-- TRUNCATE TABLE RLI_TEST.RAW.PAYMENTS;    COPY INTO ...
-- TRUNCATE TABLE RLI_TEST.RAW.ENDORSEMENTS; COPY INTO ...


-- =============================================================================
-- PATTERN 2: APPEND ONLY (Incremental Insert via Streams + Tasks)
-- =============================================================================
-- New rows are appended to RAW tables. A Snowflake Stream detects new inserts
-- and a Task processes them on a schedule or trigger.
--
-- Appropriate when:
--   - Records are immutable after creation (e.g. payments, claims)
--   - Full history must be preserved
--   - Source system provides delta files rather than full extracts
--
-- Downside: Requires deduplication downstream. Does not handle updates or
-- deletes to existing records. Handled in staging layer via QUALIFY.

-- Note: Append-only is best suited for immutable fact tables such as
-- PAYMENTS and CLAIMS where records are never updated after creation.
-- For dimension-like tables such as POLICIES and CUSTOMERS where records
-- can change, Pattern 3 (MERGE) is more appropriate.

-- =============================================================================

-- Step 1: Create stream to detect new rows in RAW table
CREATE OR REPLACE STREAM RLI_TEST.RAW.POLICIES_STREAM
    ON TABLE RLI_TEST.RAW.POLICIES
    APPEND_ONLY = TRUE;  -- only track inserts, ignore updates/deletes

-- Step 2: Create task to process stream on a schedule
CREATE OR REPLACE TASK RLI_TEST.RAW.LOAD_POLICIES_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '60 MINUTE'
    -- only run when new data exists in the stream
    WHEN SYSTEM$STREAM_HAS_DATA('RLI_TEST.RAW.POLICIES_STREAM')
AS
    -- insert only new rows detected by the stream
    INSERT INTO RLI_TEST.RAW.POLICIES
        (POLICY_ID, CUSTOMER_ID, POLICY_TYPE, EFFECTIVE_DATE, EXPIRATION_DATE, PREMIUM)
    SELECT
        POLICY_ID, CUSTOMER_ID, POLICY_TYPE, EFFECTIVE_DATE, EXPIRATION_DATE, PREMIUM
    FROM RLI_TEST.RAW.POLICIES_STREAM
    WHERE METADATA$ACTION = 'INSERT';

-- Step 3: Resume task (Snowflake tasks start in SUSPENDED state by default)
ALTER TASK RLI_TEST.RAW.LOAD_POLICIES_TASK RESUME;


-- =============================================================================
-- PATTERN 3: UPSERT VIA MERGE (Production Standard)
-- =============================================================================
-- Only rows that are new or have changed are processed. Existing unchanged
-- rows are untouched. This is the most efficient and production-appropriate
-- pattern for most insurance data scenarios.
--
-- Appropriate when:
--   - Records can be updated after creation (e.g. policy premium changes)
--   - Compute efficiency matters at scale
--   - Full row-level history must be preserved
--   - Source system provides a mix of new and updated records
--
-- Downside: More complex to implement. Requires defining what "changed" means
-- per table. Works best combined with Streams to identify changed rows.
-- =============================================================================

-- Step 1: Create stream to capture all changes (inserts, updates, deletes)
CREATE OR REPLACE STREAM RLI_TEST.RAW.POLICIES_CHANGE_STREAM
    ON TABLE RLI_TEST.RAW.POLICIES;
    -- note: no APPEND_ONLY = TRUE, so updates and deletes are also captured

-- Step 2: Create task using MERGE to upsert changed rows
CREATE OR REPLACE TASK RLI_TEST.STAGE.REFRESH_POLICIES_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '60 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('RLI_TEST.RAW.POLICIES_CHANGE_STREAM')
AS
MERGE INTO RLI_TEST.RAW.POLICIES AS target
USING (
    -- use stream as source — only contains rows that changed since last run
    SELECT *
    FROM RLI_TEST.RAW.POLICIES_CHANGE_STREAM
    WHERE METADATA$ACTION = 'INSERT'
) AS source
ON target.policy_id = source.policy_id

-- update existing rows where key fields have changed
WHEN MATCHED AND (
    target.premium          != source.premium           OR
    target.expiration_date  != source.expiration_date   OR
    target.policy_type      != source.policy_type
) THEN UPDATE SET
    target.premium          = source.premium,
    target.expiration_date  = source.expiration_date,
    target.policy_type      = source.policy_type,
    target._insrt_ts        = CURRENT_TIMESTAMP()

-- insert rows that don't exist yet
WHEN NOT MATCHED THEN INSERT
    (POLICY_ID, CUSTOMER_ID, POLICY_TYPE, EFFECTIVE_DATE, EXPIRATION_DATE, PREMIUM)
VALUES
    (source.POLICY_ID, source.CUSTOMER_ID, source.POLICY_TYPE,
     source.EFFECTIVE_DATE, source.EXPIRATION_DATE, source.PREMIUM);

-- Step 3: Resume task
ALTER TASK RLI_TEST.STAGE.REFRESH_POLICIES_TASK RESUME;


-- =============================================================================
-- PATTERN COMPARISON SUMMARY
-- =============================================================================
--
-- Pattern          | Complexity | History | Handles Updates | Cost at Scale
-- -----------------|------------|---------|-----------------|---------------
-- Truncate/Insert  | Low        | No      | Yes (full reset) | High
-- Append Only      | Medium     | Yes     | No              | Low
-- Upsert via MERGE | High       | Yes     | Yes             | Low
--
-- For this project:
--   RAW layer   → Truncate/Insert (simple, appropriate for fixed dataset)
--   STAGE layer → Views (no materialization needed at this scale)
--   MART layer  → Views refreshed on query (Snowflake Dynamic Tables would
--                 be the production upgrade path here)
--
-- =============================================================================
