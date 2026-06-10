--Just a couple scripts used during validation.

-- RLI_TEST.MART.POLICY_TOTALS_V Validation

select 
sum(closed_claim_total) + sum(op_claim_total) as claims_total, sum(payment_total) as payment_total, sum(endorsement_total) as endorsement_total, sum(prorated_premium) as prorated_premium_total, sum(premium) as premium_total
from RLI_TEST.MART.POLICY_TOTALS_V;

select 
sum(premium) as total, 'premium' as thecolumn, 'POLICIES_V' as theview      --12375475.96000000
from RLI_TEST.STAGE.POLICIES_V
union all
select 
SUM(premium * (
    DATEDIFF('day', effective_date, LEAST(CURRENT_DATE, expiration_date))
    / NULLIF(DATEDIFF('day', effective_date, expiration_date), 0)
)) as total,                                                                --11502398.88439925
'proated_premium' as thecolumn, 'POLICIES_V' as theview
from RLI_TEST.STAGE.POLICIES_V
union all
select 
sum(claim_amount) as total, 'claim_amount' as thecolumn, 'claims_v' as theview -- 10788307.34000000
from rli_test.stage.claims_v
union all
select 
sum(endorsement_amount) as total, 'endorsement_amount' as thecolumn, 'endorsements_v' as theview -- -5892.36000000
from rli_test.stage.endorsements_v
union all
select 
sum(payment_amount) as total, 'payment_amount' as thecolumn, 'payments_v' as theview --17850748.09000000
from rli_test.stage.payments_v
;
-- numbers from the above should be identical

select count(*) as invalid_loss_ratios
from  RLI_TEST.MART.POLICY_TOTALS_V
where DIV0(closed_claim_total + op_claim_total,
    prorated_premium + COALESCE(endorsement_total,0)) < 0;
-- expected: 0



 --PAYMENT_CLAIMS_TREND_V validation
SELECT MIN(month_start), MAX(month_start)
FROM RLI_TEST.MART.PAYMENT_CLAIMS_TREND_V;
-- expected: 2025-05-01 to current month

 --PAYMENT_CLAIMS_TREND_V validation
SELECT min(claim_date)
FROM RLI_TEST.STAGE.CLAIMS_V; --2024-05-26
-- expected: 2025-05-01 to current month

SELECT min(payment_date)
FROM RLI_TEST.STAGE.payments_v; --2024-05-25


-- totals in trend view should match staging layer exactly
SELECT SUM(claim_total), 'claim_total' as thecolumn, 'PAYMENT_CLAIMS_TREND_V' as theview -- 10788307.34
FROM RLI_TEST.MART.PAYMENT_CLAIMS_TREND_V
union all
SELECT SUM(payment_total), 'payment_total' as thecolumn, 'PAYMENT_CLAIMS_TREND_V' as theview --17850748.09
FROM RLI_TEST.MART.PAYMENT_CLAIMS_TREND_V
union all
SELECT SUM(payment_amount),'payment_amount' as thecolumn, 'PAYMENTS_V' as theview --17850748.09
FROM RLI_TEST.STAGE.PAYMENTS_V
union all
SELECT SUM(claim_amount) , 'claim_amount' as thecolumn, 'CLAIMS_V' as theview --10788307.34
FROM RLI_TEST.STAGE.CLAIMS_V;
-- these two numbers must match

--CUSTOMER_RISK_V validation
SELECT COUNT(*) FROM RLI_TEST.MART.CUSTOMER_RISK_V                           --327
union all
SELECT COUNT(distinct cust.customer_id) FROM RLI_TEST.STAGE.CUSTOMERS_V cust --327
    inner join RLI_TEST.STAGE.POLICIES_V pol on cust.customer_id = pol.customer_id;
-- these should match — one row per customer

SELECT SUM(total_claims) FROM RLI_TEST.MART.CUSTOMER_RISK_V --10788307.34.18
union all
SELECT SUM(claim_amount) FROM RLI_TEST.STAGE.CLAIMS_V; --10788307.34


SELECT SUM(total_payments_collected) FROM RLI_TEST.MART.CUSTOMER_RISK_V --17850748.09
union all
SELECT SUM(PAYMENT_AMOUNT) FROM RLI_TEST.STAGE.PAYMENTS_V; --17850748.09


SELECT risk_tier, COUNT(*) AS customer_count
FROM RLI_TEST.MART.CUSTOMER_RISK_V
GROUP BY risk_tier
ORDER BY customer_count DESC;

-- No Risk	 100
-- Medium	 97
-- Low	     86
-- High	     44

SELECT *
FROM RLI_TEST.MART.CUSTOMER_RISK_V
WHERE flag_open_exposure    NOT IN (0,1)
   OR flag_collection       NOT IN (0,1)
   OR flag_negative_position NOT IN (0,1)
   OR flag_high_frequency   NOT IN (0,1);
-- expected: 0 rows

-- verify status flags fire at correct thresholds
SELECT *
FROM RLI_TEST.MART.PROFITABILITY_MONITOR_V
WHERE (profitability_status = 'Unprofitable' AND loss_ratio <= 1.0)
   OR (profitability_status = 'At Risk'      AND loss_ratio <= 0.7)
   OR (profitability_status = 'Healthy'      AND loss_ratio >  0.7);
-- expected: 0 rows

-- underwriting_profit should equal adjusted_premium - total_claims
SELECT *
FROM RLI_TEST.MART.PROFITABILITY_MONITOR_V
WHERE ABS(underwriting_profit - (adjusted_premium - total_claims)) > 0.01;
-- expected: 0 rows
-- small tolerance for floating point rounding


SELECT SUM(policy_count) AS total_policy_months --1002
FROM RLI_TEST.MART.PROFITABILITY_MONITOR_V
union all
SELECT COUNT(*) AS total_policies --1002
FROM RLI_TEST.STAGE.POLICIES_V;
-- note: these won't match exactly since view groups by effective month
-- but SUM(policy_count) should equal total policies in staging;


select sum(premium), 'premium' as thecolumn, 'PROFITABILITY_MONITOR_V' as theview      --12375475.96000000
from RLI_TEST.MART.PROFITABILITY_MONITOR_V

union all

select sum(total_claims), 'total_claims' as thecolumn, 'PROFITABILITY_MONITOR_V' as theview      --10788307.34
from RLI_TEST.MART.PROFITABILITY_MONITOR_V

union all

select 
sum(premium) as total, 'premium' as thecolumn, 'POLICIES_V' as theview      --12375475.96000000
from RLI_TEST.STAGE.POLICIES_V

union all

select 
sum(claim_amount) as total, 'claim_amount' as thecolumn, 'claims_v' as theview -- 10788307.34
from rli_test.stage.claims_v;
