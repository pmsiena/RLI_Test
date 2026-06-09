create or replace view RLI_TEST.STAGE.PAYMENTS_DQ_V(
	PAYMENT_ID,
	POLICY_ID,
	PAYMENT_DATE,
	PAYMENT_AMOUNT,
	_INSRT_TS
) as
    select * from RLI_TEST.RAW.PAYMENTS
    minus 
    select * from RLI_TEST.STAGE.PAYMENTS_V;

-- Note: MINUS approach shows rejected rows without dq_reason context.
-- A tagged view pattern would provide more actionable audit detail
-- and is implemented for POLICIES via POLICIES_TAGGED_V.