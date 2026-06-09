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
    --keeping the negative payment amount for now.