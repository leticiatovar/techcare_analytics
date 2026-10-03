/*
TechCare - Analysis Queries
File: 05_analysis_queries.sql
Purpose: collect the queries that support automation prioritisation and the
project conclusions.
Engine: MySQL 8.x

Prerequisites:
- Run scripts 01 through 04.

Methodological notes:
- Phase 1 is a public sample with limited temporal coverage. Duration metrics
  use only closed tickets with timestamps in a logical order.
- Phase 2 is synthetic and demonstrates the method and proposed pilot. It does
  not represent observed results from a real company.
- The 20% scenarios are assumptions, not guaranteed savings.
*/

USE techcare_customer_support;

-- ============================================================
-- 1. PHASE 1: BASELINE
-- ============================================================

SELECT
    COUNT(*) AS total_tickets,
    SUM(ticket_status = 'Closed') AS closed_tickets,
    SUM(duracion_valida_flag = 1) AS tickets_with_valid_duration,
    ROUND(AVG(response_to_resolution_minutes) / 60, 2)
        AS avg_valid_resolution_hours,
    ROUND(
        AVG(
            CASE
                WHEN ticket_status = 'Closed'
                THEN customer_satisfaction_rating
            END
        ),
        2
    ) AS avg_closed_satisfaction
FROM fact_tickets_fase1;

-- Exploratory prioritisation by ticket subject.
-- Volume and duration thresholds are calculated from the sample itself.
WITH subject_summary AS (
    SELECT
        subject.asunto_nombre AS subject_name,
        COUNT(*) AS total_tickets,
        ROUND(
            100.0 * SUM(fact.ticket_priority IN ('Low', 'Medium')) / COUNT(*),
            2
        ) AS low_medium_priority_pct,
        ROUND(AVG(fact.response_to_resolution_minutes) / 60, 2)
            AS avg_valid_resolution_hours,
        ROUND(
            AVG(
                CASE
                    WHEN fact.ticket_status = 'Closed'
                    THEN fact.customer_satisfaction_rating
                END
            ),
            2
        ) AS avg_closed_satisfaction
    FROM fact_tickets_fase1 AS fact
    JOIN dim_asunto AS subject
        ON fact.asunto_key = subject.asunto_key
    GROUP BY subject.asunto_nombre
),
thresholds AS (
    SELECT
        AVG(total_tickets) AS avg_subject_volume,
        AVG(avg_valid_resolution_hours) AS avg_subject_duration
    FROM subject_summary
)
SELECT
    summary.subject_name,
    summary.total_tickets,
    summary.low_medium_priority_pct,
    summary.avg_valid_resolution_hours,
    summary.avg_closed_satisfaction,
    CASE
        WHEN summary.total_tickets >= thresholds.avg_subject_volume
        THEN 1 ELSE 0
    END AS volume_score,
    CASE
        WHEN summary.low_medium_priority_pct >= 50
        THEN 1 ELSE 0
    END AS priority_score,
    CASE
        WHEN summary.avg_valid_resolution_hours
             >= thresholds.avg_subject_duration
        THEN 1 ELSE 0
    END AS duration_score,
    CASE
        WHEN summary.avg_closed_satisfaction <= 3
        THEN 1 ELSE 0
    END AS satisfaction_score,
    (
        CASE
            WHEN summary.total_tickets >= thresholds.avg_subject_volume
            THEN 1 ELSE 0
        END
        + CASE
            WHEN summary.low_medium_priority_pct >= 50
            THEN 1 ELSE 0
        END
        + CASE
            WHEN summary.avg_valid_resolution_hours
                 >= thresholds.avg_subject_duration
            THEN 1 ELSE 0
        END
        + CASE
            WHEN summary.avg_closed_satisfaction <= 3
            THEN 1 ELSE 0
        END
    ) AS automation_priority_score
FROM subject_summary AS summary
CROSS JOIN thresholds
ORDER BY automation_priority_score DESC,
         summary.total_tickets DESC;

-- Exploratory Battery life scenario for the only nearly complete day.
-- The calculated time is cycle time, not direct agent labour.
SELECT
    COUNT(*) AS battery_life_tickets,
    ROUND(SUM(fact.response_to_resolution_minutes) / 60, 2)
        AS current_cycle_hours,
    ROUND(SUM(fact.response_to_resolution_minutes) / 60 * 0.20, 2)
        AS cycle_hours_reduced_20pct
FROM fact_tickets_fase1 AS fact
JOIN dim_asunto AS subject
    ON fact.asunto_key = subject.asunto_key
WHERE subject.asunto_nombre = 'Battery life'
  AND fact.duracion_valida_flag = 1
  AND fact.first_response_time >= '2023-06-01 00:00:00'
  AND fact.first_response_time < '2023-06-02 00:00:00';

-- ============================================================
-- 2. PHASE 2: TRENDS AND OPERATIONAL PERFORMANCE
-- ============================================================

SELECT
    date_dim.anio_mes AS year_month,
    COUNT(*) AS total_tickets,
    SUM(fact.ticket_status = 'Closed') AS closed_tickets,
    ROUND(AVG(fact.first_response_minutes) / 60, 2)
        AS avg_first_response_hours,
    ROUND(AVG(fact.resolution_minutes) / 60, 2)
        AS avg_resolution_hours,
    ROUND(AVG(fact.agent_handling_minutes), 2)
        AS avg_handling_minutes
FROM fact_tickets_fase2 AS fact
JOIN dim_fecha AS date_dim
    ON fact.fecha_creacion_key = date_dim.fecha_key
GROUP BY date_dim.anio_mes
ORDER BY date_dim.anio_mes;

SELECT
    fact.ticket_priority,
    COUNT(*) AS total_tickets,
    ROUND(AVG(fact.first_response_minutes) / 60, 2)
        AS avg_first_response_hours,
    ROUND(AVG(fact.resolution_minutes) / 60, 2)
        AS avg_resolution_hours,
    ROUND(AVG(fact.agent_handling_minutes), 2)
        AS avg_handling_minutes
FROM fact_tickets_fase2 AS fact
GROUP BY fact.ticket_priority
ORDER BY FIELD(fact.ticket_priority, 'Low', 'Medium', 'High', 'Critical');

SELECT
    COALESCE(fact.escalation_level, 'Not escalated') AS escalation_level_label,
    COUNT(*) AS total_tickets,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)
        AS total_pct,
    ROUND(AVG(fact.agent_handling_minutes), 2)
        AS avg_handling_minutes
FROM fact_tickets_fase2 AS fact
GROUP BY fact.escalation_level
ORDER BY avg_handling_minutes;

-- ============================================================
-- 3. AUTOMATION CANDIDATES
-- The selection rule is centralised in vw_candidatos_fase2
-- ============================================================

SELECT
    COUNT(*) AS candidate_tickets,
    ROUND(SUM(agent_handling_minutes) / 60, 2)
        AS candidate_handling_hours,
    ROUND(AVG(customer_satisfaction_rating), 2)
        AS avg_satisfaction
FROM vw_candidatos_fase2;

WITH candidates_by_subject AS (
    SELECT
        ticket_subject,
        COUNT(*) AS candidate_tickets,
        ROUND(AVG(agent_handling_minutes), 2)
            AS avg_handling_minutes,
        ROUND(SUM(agent_handling_minutes) / 60, 2)
            AS handling_hours,
        ROUND(AVG(customer_satisfaction_rating), 2)
            AS avg_satisfaction
    FROM vw_candidatos_fase2
    GROUP BY ticket_subject
)
SELECT
    ticket_subject,
    candidate_tickets,
    avg_handling_minutes,
    handling_hours,
    avg_satisfaction,
    DENSE_RANK() OVER (
        ORDER BY handling_hours DESC
    ) AS handling_hours_rank
FROM candidates_by_subject
ORDER BY handling_hours_rank, ticket_subject;

-- Battery life candidate composition by product and channel.
SELECT
    product_purchased,
    ticket_channel,
    COUNT(*) AS candidate_tickets,
    ROUND(SUM(agent_handling_minutes) / 60, 2) AS handling_hours
FROM vw_battery_life_candidatos
GROUP BY product_purchased, ticket_channel
ORDER BY candidate_tickets DESC, product_purchased, ticket_channel;

-- ============================================================
-- 4. BATTERY LIFE STANDARDISATION
-- Source text is queried only to evaluate repetition.
-- ============================================================

WITH resolution_counts AS (
    SELECT
        REGEXP_REPLACE(
            LOWER(TRIM(source.resolution)),
            '[[:space:]]+',
            ' '
        ) AS normalised_resolution,
        COUNT(*) AS frequency
    FROM customer_support_tickets_phase2 AS source
    JOIN vw_battery_life_candidatos AS candidate
        ON source.ticket_id = candidate.ticket_id
    WHERE source.resolution IS NOT NULL
      AND TRIM(source.resolution) <> ''
    GROUP BY normalised_resolution
)
SELECT
    SUM(frequency) AS tickets_with_resolution,
    COUNT(*) AS distinct_resolutions,
    SUM(frequency = 1) AS single_use_resolutions,
    SUM(frequency > 1) AS repeated_resolutions,
    MAX(frequency) AS maximum_repetition
FROM resolution_counts;

WITH context_free_descriptions AS (
    SELECT
        REGEXP_REPLACE(
            REPLACE(
                REPLACE(
                    LOWER(TRIM(source.ticket_description)),
                    LOWER(TRIM(source.product_purchased)),
                    '[product]'
                ),
                LOWER(TRIM(source.ticket_channel)),
                '[channel]'
            ),
            '[[:space:]]+',
            ' '
        ) AS description_pattern
    FROM customer_support_tickets_phase2 AS source
    JOIN vw_battery_life_candidatos AS candidate
        ON source.ticket_id = candidate.ticket_id
    WHERE source.ticket_description IS NOT NULL
      AND TRIM(source.ticket_description) <> ''
)
SELECT
    COUNT(*) AS total_tickets,
    COUNT(DISTINCT description_pattern) AS distinct_patterns
FROM context_free_descriptions;

-- Text repetition supports the standardisation hypothesis, but it does not
-- prove that the underlying procedure is identical in every case.

-- ============================================================
-- 5. HYPOTHETICAL CAPACITY-RELEASE SCENARIO
-- ============================================================

SELECT
    COUNT(*) AS battery_life_tickets,
    ROUND(SUM(agent_handling_minutes) / 60, 2)
        AS current_handling_hours,
    ROUND(SUM(agent_handling_minutes) / 60 * 0.20, 2)
        AS potential_hours_released_20pct
FROM vw_battery_life_candidatos;

-- The 20% assumption must be validated through a pilot. It is not a
-- guaranteed financial saving or an observed production result.
