-- =============================================================================
-- RLI Insurance ~ Senior Data Engineer ~ Take Home ~ Raw Ingestion Script
-- =============================================================================
-- Purpose: Creates the RLI_TEST database, schemas, internal stage, and loads
--          all five source files into the RAW schema.
--
-- Prerequisites:
--   1. Source files uploaded to the Snowflake internal stage (see PUT commands below)
--   2. Run this script before Stage or Mart scripts
--
-- To upload files via SnowSQL CLI (run locally, not in Snowsight):
--   PUT file:///path/to/customers.csv     @RLI_TEST.RAW.raw_stage;
--   PUT file:///path/to/policies.csv      @RLI_TEST.RAW.raw_stage;
--   PUT file:///path/to/claims.csv        @RLI_TEST.RAW.raw_stage;
--   PUT file:///path/to/payments.csv      @RLI_TEST.RAW.raw_stage;
--   PUT file:///path/to/endorsements.json @RLI_TEST.RAW.raw_stage;
-- =============================================================================


-- -----------------------------------------------------------------------------
-- STEP 1: Database and schema setup
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS RLI_TEST;
CREATE SCHEMA IF NOT EXISTS RLI_TEST.RAW;
CREATE SCHEMA IF NOT EXISTS RLI_TEST.STAGE;
CREATE SCHEMA IF NOT EXISTS RLI_TEST.MART;

-- -----------------------------------------------------------------------------
-- STEP 2: Internal stage
-- -----------------------------------------------------------------------------
CREATE OR REPLACE STAGE RLI_TEST.RAW.raw_stage
    FILE_FORMAT = (
        TYPE                        = 'CSV'
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        SKIP_HEADER                 = 1
    );

-- -----------------------------------------------------------------------------
-- STEP 3: Load CSV files
-- Note: _insrt_ts is omitted from column list so DEFAULT CURRENT_TIMESTAMP()
--       fires automatically rather than being overridden with NULL
-- -----------------------------------------------------------------------------

-- Customers
COPY INTO RLI_TEST.RAW.CUSTOMERS
    (CUSTOMER_ID, CUSTOMER_NAME, STATE, INDUSTRY)
FROM @RLI_TEST.RAW.raw_stage/customers.csv
FILE_FORMAT = (
    TYPE                        = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER                 = 1
);

-- Policies
COPY INTO RLI_TEST.RAW.POLICIES
    (POLICY_ID, CUSTOMER_ID, POLICY_TYPE, EFFECTIVE_DATE, EXPIRATION_DATE, PREMIUM)
FROM @RLI_TEST.RAW.raw_stage/policies.csv
FILE_FORMAT = (
    TYPE                        = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER                 = 1
);

-- Claims
COPY INTO RLI_TEST.RAW.CLAIMS
    (CLAIM_ID, POLICY_ID, CLAIM_DATE, CLAIM_AMOUNT, CLAIM_STATUS)
FROM @RLI_TEST.RAW.raw_stage/claims.csv
FILE_FORMAT = (
    TYPE                        = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER                 = 1
);

-- Payments
COPY INTO RLI_TEST.RAW.PAYMENTS
    (PAYMENT_ID, POLICY_ID, PAYMENT_DATE, PAYMENT_AMOUNT)
FROM @RLI_TEST.RAW.raw_stage/payments.csv
FILE_FORMAT = (
    TYPE                        = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER                 = 1
)

-- -----------------------------------------------------------------------------
-- STEP 4: Load JSON file (endorsements)
-- Note: JSON requires a SELECT with explicit field extraction from $1 VARIANT
-- -----------------------------------------------------------------------------
COPY INTO RLI_TEST.RAW.ENDORSEMENTS
    (ENDORSEMENT_ID, POLICY_ID, ENDORSEMENT_TYPE, ENDORSEMENT_DATE, ENDORSEMENT_AMOUNT)
FROM (
    SELECT
        $1:endorsement_id::NUMBER       AS ENDORSEMENT_ID,
        $1:policy_id::NUMBER            AS POLICY_ID,
        $1:endorsement_type::VARCHAR    AS ENDORSEMENT_TYPE,
        $1:endorsement_date::DATE       AS ENDORSEMENT_DATE,
        $1:endorsement_amount::NUMBER   AS ENDORSEMENT_AMOUNT
    FROM @RLI_TEST.RAW.raw_stage/endorsements.json
)
FILE_FORMAT = (TYPE = 'JSON');

-- -----------------------------------------------------------------------------
-- STEP 5: Verify row counts
-- Expected: CUSTOMERS=352, POLICIES=1004, CLAIMS=425, PAYMENTS=3554, ENDORSEMENTS=50
-- -----------------------------------------------------------------------------
SELECT 'CUSTOMERS'   AS table_name, COUNT(*) AS row_count FROM RLI_TEST.RAW.CUSTOMERS   UNION ALL
SELECT 'POLICIES'    AS table_name, COUNT(*) AS row_count FROM RLI_TEST.RAW.POLICIES    UNION ALL
SELECT 'CLAIMS'      AS table_name, COUNT(*) AS row_count FROM RLI_TEST.RAW.CLAIMS      UNION ALL
SELECT 'PAYMENTS'    AS table_name, COUNT(*) AS row_count FROM RLI_TEST.RAW.PAYMENTS    UNION ALL
SELECT 'ENDORSEMENTS'AS table_name, COUNT(*) AS row_count FROM RLI_TEST.RAW.ENDORSEMENTS
ORDER BY table_name;