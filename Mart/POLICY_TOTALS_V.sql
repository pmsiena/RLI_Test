create or replace view RLI_TEST.MART.POLICY_TOTALS_V(
	CLOSED_CLAIM_TOTAL,
	OP_CLAIM_TOTAL,
	PAYMENT_TOTAL,
	ENDORSEMENT_TOTAL,
	PRORATED_PREMIUM,
	POLICY_ID,
	CUSTOMER_ID,
	POLICY_TYPE,
	EFFECTIVE_DATE,
	EXPIRATION_DATE,
	PREMIUM,
	CUSTOMER_NAME,
	STATE,
	INDUSTRY
) as 
with closed_claims_by_policyId as (
    select SUM(claim_amount) as closed_claim_total, policy_id
    from RLI_TEST.STAGE.CLAIMS_V
    where claim_status = 'Closed'
    group by policy_id
)

,open_pending_claims_by_policyId as (
    select SUM(claim_amount) as op_claim_total, policy_id
    from RLI_TEST.STAGE.CLAIMS_V
    where claim_status in ('Open','Pending')
    group by policy_id
)

,payments_by_policyId as (
    select SUM(payment_amount) as payment_total, policy_id
    from RLI_TEST.STAGE.payments_v
    group by policy_id
)
,endorsements_by_policyId as (
select policy_id, sum(endorsement_amount)  as endorsement_total
from rli_test.stage.endorsements_v
group by policy_id
)

select 
    clo_cla.closed_claim_total, 
    op_cla.op_claim_total,
    payment_total, 
    endorsement_total,
    pol.premium * (
        DIV0(
            DATEDIFF('day',  pol.effective_date, LEAST(CURRENT_DATE,  pol.expiration_date)),
            DATEDIFF('day',  pol.effective_date,  pol.expiration_date)
        )
    )     AS prorated_premium,
    pol.POLICY_ID, pol.CUSTOMER_ID, pol.POLICY_TYPE, pol.EFFECTIVE_DATE, pol.EXPIRATION_DATE, pol.PREMIUM,
    cust.CUSTOMER_NAME, cust.STATE, cust.INDUSTRY
from  RLI_TEST.STAGE.policies_V pol
left join open_pending_claims_by_policyId op_cla on op_cla.policy_id = pol.policy_id
left join closed_claims_by_policyId clo_cla on clo_cla.policy_id = pol.policy_id
left join payments_by_policyId pay on pay.policy_id = pol.policy_id
left join endorsements_by_policyId endo on endo.policy_id = pol.policy_id
left join RLI_TEST.STAGE.CUSTOMERS_V cust on cust.customer_id = pol.customer_id
;