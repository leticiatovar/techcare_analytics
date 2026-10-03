/*
TechCare - Data Quality Checks
File: 04_data_quality_checks.sql
Purpose: validate integrity, row counts, relationships, and results across
the dimensional model and business views.
Engine: MySQL 8.x

Expected results:
- Row-count difference equals 0 for both phases.
- Duplicate identifiers and unmatched relationships equal 0.
- 26,062 Phase 2 candidates.
- 2,175 Battery life candidates and 752.33 handling hours.
*/

USE techcare_customer_support;

-- ============================================================
-- 1. SOURCE-TABLE INTEGRITY
-- ============================================================

SELECT
    'Phase 1' AS phase,
    COUNT(*) AS row_count,
    COUNT(DISTINCT ticket_id) AS unique_tickets,
    COUNT(*) - COUNT(DISTINCT ticket_id) AS duplicate_ids
FROM customer_support_tickets_phase1

UNION ALL

SELECT
    'Phase 2',
    COUNT(*),
    COUNT(DISTINCT ticket_id),
    COUNT(*) - COUNT(DISTINCT ticket_id)
FROM customer_support_tickets_phase2;

-- ============================================================
-- 2. SOURCE-TO-FACT RECONCILIATION
-- ============================================================

SELECT
    'Phase 1' AS phase,
    (SELECT COUNT(*)
     FROM customer_support_tickets_phase1) AS source_rows,
    (SELECT COUNT(*)
     FROM fact_tickets_fase1) AS fact_rows,
    (SELECT COUNT(*)
     FROM customer_support_tickets_phase1)
    -
    (SELECT COUNT(*)
     FROM fact_tickets_fase1) AS row_difference

UNION ALL

SELECT
    'Phase 2',
    (SELECT COUNT(*)
     FROM customer_support_tickets_phase2),
    (SELECT COUNT(*)
     FROM fact_tickets_fase2),
    (SELECT COUNT(*)
     FROM customer_support_tickets_phase2)
    -
    (SELECT COUNT(*)
     FROM fact_tickets_fase2);

-- ============================================================
-- 3. DIMENSION VALIDATION
-- Each name or identifier must be unique within its dimension
-- ============================================================

SELECT
    'dim_fase' AS dimension,
    COUNT(*) AS row_count,
    COUNT(DISTINCT fase_nombre) AS unique_values,
    COUNT(*) - COUNT(DISTINCT fase_nombre) AS duplicates
FROM dim_fase

UNION ALL

SELECT
    'dim_asunto',
    COUNT(*),
    COUNT(DISTINCT asunto_nombre),
    COUNT(*) - COUNT(DISTINCT asunto_nombre)
FROM dim_asunto

UNION ALL

SELECT
    'dim_producto',
    COUNT(*),
    COUNT(DISTINCT producto_nombre),
    COUNT(*) - COUNT(DISTINCT producto_nombre)
FROM dim_producto

UNION ALL

SELECT
    'dim_canal',
    COUNT(*),
    COUNT(DISTINCT canal_nombre),
    COUNT(*) - COUNT(DISTINCT canal_nombre)
FROM dim_canal

UNION ALL

SELECT
    'dim_agente',
    COUNT(*),
    COUNT(DISTINCT agente_id),
    COUNT(*) - COUNT(DISTINCT agente_id)
FROM dim_agente

UNION ALL

SELECT
    'dim_equipo',
    COUNT(*),
    COUNT(DISTINCT equipo_nombre),
    COUNT(*) - COUNT(DISTINCT equipo_nombre)
FROM dim_equipo;

-- The agent dimension excludes team because one agent may be associated
-- with multiple teams in the source dataset.
SELECT
    COUNT(*) AS agents_in_multiple_teams
FROM (
    SELECT assigned_agent_id
    FROM customer_support_tickets_phase2
    GROUP BY assigned_agent_id
    HAVING COUNT(DISTINCT assigned_team) > 1
) AS multi_team_agents;

-- ============================================================
-- 4. PHASE 1 RELATIONSHIPS
-- ============================================================

SELECT
    SUM(phase.fase_key IS NULL) AS unmatched_phases,
    SUM(subject.asunto_key IS NULL) AS unmatched_subjects,
    SUM(product.producto_key IS NULL) AS unmatched_products,
    SUM(channel.canal_key IS NULL) AS unmatched_channels
FROM fact_tickets_fase1 AS fact
LEFT JOIN dim_fase AS phase
    ON fact.fase_key = phase.fase_key
LEFT JOIN dim_asunto AS subject
    ON fact.asunto_key = subject.asunto_key
LEFT JOIN dim_producto AS product
    ON fact.producto_key = product.producto_key
LEFT JOIN dim_canal AS channel
    ON fact.canal_key = channel.canal_key;

-- ============================================================
-- 5. PHASE 2 RELATIONSHIPS
-- ============================================================

SELECT
    SUM(phase.fase_key IS NULL) AS unmatched_phases,
    SUM(date_dim.fecha_key IS NULL) AS unmatched_dates,
    SUM(subject.asunto_key IS NULL) AS unmatched_subjects,
    SUM(product.producto_key IS NULL) AS unmatched_products,
    SUM(channel.canal_key IS NULL) AS unmatched_channels,
    SUM(agent.agente_key IS NULL) AS unmatched_agents,
    SUM(team.equipo_key IS NULL) AS unmatched_teams
FROM fact_tickets_fase2 AS fact
LEFT JOIN dim_fase AS phase
    ON fact.fase_key = phase.fase_key
LEFT JOIN dim_fecha AS date_dim
    ON fact.fecha_creacion_key = date_dim.fecha_key
LEFT JOIN dim_asunto AS subject
    ON fact.asunto_key = subject.asunto_key
LEFT JOIN dim_producto AS product
    ON fact.producto_key = product.producto_key
LEFT JOIN dim_canal AS channel
    ON fact.canal_key = channel.canal_key
LEFT JOIN dim_agente AS agent
    ON fact.agente_key = agent.agente_key
LEFT JOIN dim_equipo AS team
    ON fact.equipo_key = team.equipo_key;

-- ============================================================
-- 6. FACT-TABLE DERIVED METRICS
-- ============================================================

SELECT
    COUNT(*) AS phase1_tickets,
    SUM(ticket_status = 'Closed') AS closed_tickets,
    SUM(duracion_valida_flag = 1) AS valid_durations,
    SUM(duracion_valida_flag = 0) AS invalid_durations,
    ROUND(AVG(response_to_resolution_minutes) / 60, 2)
        AS avg_resolution_hours,
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

SELECT
    COUNT(*) AS phase2_tickets,
    MIN(ticket_created_at) AS first_ticket,
    MAX(ticket_created_at) AS last_ticket,
    ROUND(AVG(first_response_minutes) / 60, 2)
        AS avg_first_response_hours,
    ROUND(AVG(resolution_minutes) / 60, 2)
        AS avg_resolution_hours,
    ROUND(AVG(agent_handling_minutes), 2)
        AS avg_handling_minutes
FROM fact_tickets_fase2;

-- ============================================================
-- 7. BUSINESS-VIEW VALIDATION
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM vw_candidatos_fase2) AS phase2_candidates,
    (SELECT COUNT(*)
     FROM vw_battery_life_candidatos) AS battery_life_candidates,
    (SELECT ROUND(SUM(agent_handling_minutes) / 60, 2)
     FROM vw_battery_life_candidatos) AS battery_life_handling_hours,
    (SELECT ROUND(AVG(customer_satisfaction_rating), 2)
     FROM vw_battery_life_candidatos) AS battery_life_satisfaction;
