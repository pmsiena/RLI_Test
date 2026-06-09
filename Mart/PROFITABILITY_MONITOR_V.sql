create or replace view RLI_TEST.MART.PROFITABILITY_MONITOR_V(
	REPORT_MONTH,
	POLICY_TYPE,
	POLICY_COUNT,
	PREMIUM,
	PRORATED_PREMIUM,
	ADJUSTED_PREMIUM,
	COLLECTED_PREMIUM,
	COLLECTION_GAP,
	CLOSED_CLAIMS,
	OPEN_CLAIMS,
	TOTAL_CLAIMS,
	UNDERWRITING_PROFIT,
	ROLLING_UNDERWRITING_PROFIT,
	ROLLING_TOTAL_CLAIMS,
	ROLLING_COLLECTED_PREMIUM,
	LOSS_RATIO,
	ROLLING_LOSS_RATIO,
	PROFITABILITY_STATUS
) as
WITH monthly_totals AS (
    SELECT
        -- note the time series is based on effective month
        DATE_TRUNC('month', pol.effective_date)         AS effective_month,
        pol.policy_type,

        -- volume
        COUNT(DISTINCT pol.policy_id)                   AS policy_count,

        -- premium
        SUM(pol.premium)                                AS premium,
        SUM(pol.prorated_premium)                       AS prorated_premium,
        SUM(pol.payment_total)                          AS collected_premium,
        SUM(pol.endorsement_total)                      AS endorsement_total,
        SUM(pol.prorated_premium)
            + COALESCE(SUM(pol.endorsement_total), 0)   AS adjusted_premium,

        -- claims
        SUM(pol.closed_claim_total)                     AS closed_claims,
        SUM(pol.op_claim_total)                         AS open_claims,
        SUM(pol.closed_claim_total)
            + SUM(pol.op_claim_total)                   AS total_claims,

        -- profitability
        SUM(pol.prorated_premium)
            + COALESCE(SUM(pol.endorsement_total), 0)
            - SUM(pol.closed_claim_total)
            - SUM(pol.op_claim_total)                   AS underwriting_profit,

        -- collection gap
        SUM(pol.premium)
            - SUM(pol.payment_total)                    AS collection_gap

    FROM RLI_TEST.MART.POLICY_TOTALS_V pol
    GROUP BY DATE_TRUNC('month', pol.effective_date), pol.policy_type

)

SELECT
    effective_month,
    policy_type,
    policy_count,
    premium,
    prorated_premium,
    adjusted_premium,
    collected_premium,
    collection_gap,
    closed_claims,
    open_claims,
    total_claims,
    underwriting_profit,

    -- rolling trends
    SUM(underwriting_profit) OVER (
        PARTITION BY policy_type
        ORDER BY effective_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                   AS rolling_underwriting_profit,

    SUM(total_claims) OVER (
        PARTITION BY policy_type
        ORDER BY effective_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                   AS rolling_total_claims,

    SUM(collected_premium) OVER (
        PARTITION BY policy_type
        ORDER BY effective_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                   AS rolling_collected_premium,

    -- loss ratio
    DIV0(total_claims, adjusted_premium)                AS loss_ratio,

    -- rolling loss ratio
    -- answer to profitability status and claims exposure over time
    DIV0(
        SUM(total_claims) OVER (
            PARTITION BY policy_type
            ORDER BY effective_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        NULLIF(SUM(adjusted_premium) OVER (
            PARTITION BY policy_type
            ORDER BY effective_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 0)
    )                                                   AS rolling_loss_ratio,

    -- answer to profitability status and claims exposure within a month
    CASE
        WHEN DIV0(total_claims, 
            adjusted_premium) > 1.0                     THEN 'Unprofitable'
        WHEN DIV0(total_claims, 
            adjusted_premium) > 0.7                     THEN 'At Risk'
        ELSE                                                 'Healthy'
    END                                                 AS profitability_status

FROM monthly_totals
ORDER BY policy_type, effective_month;