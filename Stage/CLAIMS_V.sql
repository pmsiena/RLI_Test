create or replace view RLI_TEST.STAGE.CLAIMS_V(
	CLAIM_ID,
	POLICY_ID,
	CLAIM_DATE,
	CLAIM_AMOUNT,
	CLAIM_STATUS,
	_INSRT_TS
) as
    select cla.* 
    from RLI_TEST.RAW.CLAIMS cla
    where
    -- check against STAGE not RAW 
    -- excludes claims whose policies were filtered out for data quality reasons
    cla.policy_id IN (
        SELECT policy_id 
        FROM RLI_TEST.STAGE.POLICIES_V
    )
    AND cla.claim_id NOT IN (
        SELECT claim_id
        FROM RLI_TEST.RAW.CLAIMS
        GROUP BY claim_id
        HAVING COUNT(*) > 1
    )