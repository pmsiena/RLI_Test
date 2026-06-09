create or replace view RLI_TEST.STAGE.POLICIES_TAGGED_V(
	POLICY_ID,
	CUSTOMER_ID,
	POLICY_TYPE,
	EFFECTIVE_DATE,
	EXPIRATION_DATE,
	PREMIUM,
	_INSRT_TS,
	DQ_REASON
) as
SELECT
    *,
    CASE
        WHEN premium < 0 or premium is null      THEN 'INVALID_AMOUNT'
        when effective_date >= expiration_date   THEN 'INVALID_DATES'
        WHEN customer_id NOT IN (
            SELECT customer_id FROM RLI_TEST.RAW.CUSTOMERS
        )                                        THEN 'ORPHAN_FK'
        WHEN COUNT(*) OVER (
            PARTITION BY policy_id
        ) > 1                                    THEN 'DUPLICATE_PK'
        ELSE NULL
    END AS dq_reason
FROM RLI_TEST.RAW.POLICIES;