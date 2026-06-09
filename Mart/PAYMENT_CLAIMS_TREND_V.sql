create or replace view RLI_TEST.MART.PAYMENT_CLAIMS_TREND_V(
	MONTH_START,
	POLICY_TYPE,
	INDUSTRY,
	STATE,
	CLAIM_COUNT,
	CLAIM_TOTAL,
	CLOSED_CLAIM_TOTAL,
	OPEN_CLAIM_TOTAL,
	PAYMENT_COUNT,
	PAYMENT_TOTAL,
	ROLLING_CLAIM_TOTAL,
	ROLLING_PAYMENT_TOTAL
) as 
with calendar AS (
--useful to see the full time series and takes the load off analytics solutions
SELECT 
DATEADD('month', ROW_NUMBER() OVER (ORDER BY 1) - 1, '2025-05-01')::DATE AS month_start --min month should not change
FROM TABLE(GENERATOR(ROWCOUNT => 120))  -- Rowcount needs to be hardcoded in Snowflake. 120 = 10 years, more than enough
QUALIFY month_start <= CURRENT_DATE()
)

,policy_segments AS (
    -- distinct segments to cross join
    SELECT DISTINCT 
        policy_type,
        industry,
        state
    FROM RLI_TEST.STAGE.POLICIES_V pol
    JOIN RLI_TEST.STAGE.CUSTOMERS_V cust on cust.customer_id = pol.customer_id
)

,monthly_claims as (
select 
    DATE_TRUNC('month', claim_date)         AS claim_month,
    count(cla.claim_id)                         as claim_count,
    sum(cla.claim_amount)                       as claim_total,
    SUM(CASE WHEN cla.claim_status = 'Closed'
                THEN cla.claim_amount ELSE 0 END)    AS closed_claim_total,
    SUM(CASE WHEN cla.claim_status IN ('Open','Pending')
                THEN cla.claim_amount ELSE 0 END)    AS open_claim_total,
    cust.industry, 
    cust.state,
    pol.policy_type
from RLI_TEST.STAGE.CLAIMS_V cla
left join RLI_TEST.STAGE.policies_v pol on cla.policy_id = pol.policy_id
left join RLI_TEST.STAGE.customers_v cust on cust.customer_id = pol.customer_id
group by 
DATE_TRUNC('month', claim_date),
    cust.industry, 
    cust.state,
    pol.policy_type
)

,monthly_payments as (
select 
DATE_TRUNC('month', payment_date)         AS payment_month,
count(pay.payment_id)                         as payment_count,
sum(pay.payment_amount)                       as payment_total,
    cust.industry, 
    cust.state,
    pol.policy_type
from RLI_TEST.STAGE.Payments_v pay
left join RLI_TEST.STAGE.policies_v pol on pay.policy_id = pol.policy_id
left join RLI_TEST.STAGE.customers_v cust on cust.customer_id = pol.customer_id
group by 
DATE_TRUNC('month', payment_date),
    cust.industry, 
    cust.state,
    pol.policy_type
)

select 
    cal.month_start,
    seg.policy_type, seg.industry, seg.state,
    COALESCE(mc.claim_count, 0)             AS claim_count,
    COALESCE(mc.claim_total, 0)             AS claim_total,
    COALESCE(mc.closed_claim_total, 0)      AS closed_claim_total,
    COALESCE(mc.open_claim_total, 0)        AS open_claim_total,
    COALESCE(mp.payment_count, 0)           AS payment_count,
    COALESCE(mp.payment_total, 0)           AS payment_total,

    SUM(COALESCE(mc.claim_total, 0)) OVER (
        PARTITION BY seg.policy_type, seg.industry, seg.state
        ORDER BY cal.month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                           AS rolling_claim_total,
    
    SUM(COALESCE(mp.payment_total, 0)) OVER (
        PARTITION BY seg.policy_type, seg.industry, seg.state
        ORDER BY cal.month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                           AS rolling_payment_total
from calendar cal
cross join policy_segments seg
left join monthly_claims mc on mc.claim_month = cal.month_start and mc.state = seg.state and mc.policy_type = seg.policy_type and mc.industry = seg.industry
left join monthly_payments mp on mp.payment_month = cal.month_start and mp.state = seg.state and mp.policy_type = seg.policy_type and mp.industry = seg.industry
order by seg.policy_type, seg.industry, seg.state,  cal.month_start
;