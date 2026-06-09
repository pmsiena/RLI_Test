create or replace view RLI_TEST.STAGE.PAYMENTS_V(
	PAYMENT_ID,
	POLICY_ID,
	PAYMENT_DATE,
	PAYMENT_AMOUNT,
	_INSRT_TS
) as
    SELECT
        pay.*
    FROM RLI_TEST.RAW.PAYMENTS pay
    -- keeping the negative payment amount for now, as it could be a credit.
    -- check against STAGE not RAW 
    where 
    pay.policy_id IN (
        SELECT policy_id 
        FROM RLI_TEST.STAGE.POLICIES_V
    )
