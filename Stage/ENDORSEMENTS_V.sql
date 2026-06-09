create or replace view RLI_TEST.STAGE.ENDORSEMENTS_V(
	ENDORSEMENT_AMOUNT,
	ENDORSEMENT_DATE,
	ENDORSEMENT_ID,
	ENDORSEMENT_TYPE,
	POLICY_ID,
	_INSRT_TS
) as
    SELECT
        endo.*
    FROM RLI_TEST.RAW.ENDORSEMENTS endo
    --no validation issues found. View is likely unnecessary. Keeping format for consistency
        