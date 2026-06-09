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
    left join rli_test.raw.policies pol on pol.policy_id = cla.policy_id
    where 
        pol.policy_id is not null
        --removes individual instance of missing foreign key
    -- QUALIFY COUNT(*) OVER (PARTITION BY cla.claim_id) = 1;
    -- primary key qualifier not needed for existing dataset