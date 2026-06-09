create or replace view RLI_TEST.STAGE.CLAIMS_DQ_V(
	CLAIM_ID,
	POLICY_ID,
	CLAIM_DATE,
	CLAIM_AMOUNT,
	CLAIM_STATUS,
	_INSRT_TS
) as
    select * from RLI_TEST.RAW.CLAIMS
    minus 
    select * from RLI_TEST.STAGE.CLAIMS_V;