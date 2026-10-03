/*
TechCare - Business Views
File: 03_business_views.sql
Purpose: centralise the selection rules used by Power BI and by the
automation-candidate analysis.
Engine: MySQL 8.x

Prerequisite: run 02_dimensional_model.sql.
*/

USE techcare_customer_support;

-- ============================================================
-- 1. PHASE 2 CANDIDATE TICKETS
-- Rule: closed, non-escalated, and Low or Medium priority
-- ============================================================

CREATE OR REPLACE VIEW vw_candidatos_fase2 AS
SELECT
    fact.ticket_id,
    fact.fase_key,
    phase.fase_nombre,
    fact.fecha_creacion_key,
    date_dim.fecha AS ticket_created_date,
    fact.asunto_key,
    subject.asunto_nombre AS ticket_subject,
    fact.producto_key,
    product.producto_nombre AS product_purchased,
    fact.canal_key,
    channel.canal_nombre AS ticket_channel,
    fact.agente_key,
    agent.agente_id AS assigned_agent_id,
    fact.equipo_key,
    team.equipo_nombre AS assigned_team,
    fact.ticket_type,
    fact.ticket_status,
    fact.ticket_priority,
    fact.ticket_created_at,
    fact.first_response_at,
    fact.resolved_at,
    fact.escalated_flag,
    fact.first_response_minutes,
    fact.resolution_minutes,
    fact.agent_handling_minutes,
    fact.customer_satisfaction_rating
FROM fact_tickets_fase2 AS fact
JOIN dim_fase AS phase
    ON fact.fase_key = phase.fase_key
JOIN dim_fecha AS date_dim
    ON fact.fecha_creacion_key = date_dim.fecha_key
JOIN dim_asunto AS subject
    ON fact.asunto_key = subject.asunto_key
JOIN dim_producto AS product
    ON fact.producto_key = product.producto_key
JOIN dim_canal AS channel
    ON fact.canal_key = channel.canal_key
JOIN dim_agente AS agent
    ON fact.agente_key = agent.agente_key
JOIN dim_equipo AS team
    ON fact.equipo_key = team.equipo_key
WHERE fact.ticket_status = 'Closed'
  AND fact.escalated_flag = 0
  AND fact.ticket_priority IN ('Low', 'Medium');

-- ============================================================
-- 2. BATTERY LIFE CANDIDATES
-- ============================================================

CREATE OR REPLACE VIEW vw_battery_life_candidatos AS
SELECT
    ticket_id,
    fecha_creacion_key,
    ticket_created_date,
    asunto_key,
    ticket_subject,
    producto_key,
    product_purchased,
    canal_key,
    ticket_channel,
    agente_key,
    assigned_agent_id,
    equipo_key,
    assigned_team,
    first_response_minutes,
    resolution_minutes,
    agent_handling_minutes,
    agent_handling_minutes / 60.0 AS agent_handling_hours,
    customer_satisfaction_rating
FROM vw_candidatos_fase2
WHERE ticket_subject = 'Battery life';
