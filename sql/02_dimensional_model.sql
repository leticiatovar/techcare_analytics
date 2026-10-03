/*
TechCare - Dimensional Model
File: 02_dimensional_model.sql
Purpose: create and populate the dimensions and fact tables used by the
Power BI analytical model.
Engine: MySQL 8.x

Prerequisites:
- Run 01_database_setup.sql.
- Load both source tables.

This script is designed to run once against a new schema. Subsequent checks
are defined in 04_data_quality_checks.sql.
*/

USE techcare_customer_support;

-- ============================================================
-- 1. DATE DIMENSION
-- ============================================================

CREATE TABLE dim_fecha (
    fecha_key INT PRIMARY KEY,
    fecha DATE NOT NULL UNIQUE,
    anio SMALLINT NOT NULL,
    trimestre_numero TINYINT NOT NULL,
    mes_numero TINYINT NOT NULL,
    mes_nombre VARCHAR(10) NOT NULL,
    anio_mes CHAR(7) NOT NULL,
    inicio_mes DATE NOT NULL
);

INSERT INTO dim_fecha (
    fecha_key,
    fecha,
    anio,
    trimestre_numero,
    mes_numero,
    mes_nombre,
    anio_mes,
    inicio_mes
)
WITH RECURSIVE calendar_dates AS (
    SELECT DATE('2023-01-01') AS fecha

    UNION ALL

    SELECT DATE_ADD(fecha, INTERVAL 1 DAY)
    FROM calendar_dates
    WHERE fecha < '2023-06-30'
)
SELECT
    CAST(DATE_FORMAT(fecha, '%Y%m%d') AS UNSIGNED),
    fecha,
    YEAR(fecha),
    QUARTER(fecha),
    MONTH(fecha),
    CASE MONTH(fecha)
        WHEN 1 THEN 'Enero'
        WHEN 2 THEN 'Febrero'
        WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Mayo'
        WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'
    END,
    DATE_FORMAT(fecha, '%Y-%m'),
    CAST(DATE_FORMAT(fecha, '%Y-%m-01') AS DATE)
FROM calendar_dates;

-- ============================================================
-- 2. CONFORMED DIMENSIONS
-- ============================================================

CREATE TABLE dim_fase (
    fase_key INT AUTO_INCREMENT PRIMARY KEY,
    fase_nombre VARCHAR(20) NOT NULL UNIQUE,
    origen_datos VARCHAR(30) NOT NULL
);

CREATE TABLE dim_asunto (
    asunto_key INT AUTO_INCREMENT PRIMARY KEY,
    asunto_nombre VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE dim_producto (
    producto_key INT AUTO_INCREMENT PRIMARY KEY,
    producto_nombre VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE dim_canal (
    canal_key INT AUTO_INCREMENT PRIMARY KEY,
    canal_nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dim_agente (
    agente_key INT AUTO_INCREMENT PRIMARY KEY,
    agente_id VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dim_equipo (
    equipo_key INT AUTO_INCREMENT PRIMARY KEY,
    equipo_nombre VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO dim_fase (
    fase_nombre,
    origen_datos
)
VALUES
    ('Fase 1', 'Muestra publica'),
    ('Fase 2', 'Simulacion sintetica');

INSERT INTO dim_asunto (asunto_nombre)
SELECT asunto_nombre
FROM (
    SELECT ticket_subject AS asunto_nombre
    FROM customer_support_tickets_phase1

    UNION

    SELECT ticket_subject AS asunto_nombre
    FROM customer_support_tickets_phase2
) AS unified_subjects
WHERE asunto_nombre IS NOT NULL
ORDER BY asunto_nombre;

INSERT INTO dim_producto (producto_nombre)
SELECT producto_nombre
FROM (
    SELECT product_purchased AS producto_nombre
    FROM customer_support_tickets_phase1

    UNION

    SELECT product_purchased AS producto_nombre
    FROM customer_support_tickets_phase2
) AS unified_products
WHERE producto_nombre IS NOT NULL
ORDER BY producto_nombre;

INSERT INTO dim_canal (canal_nombre)
SELECT canal_nombre
FROM (
    SELECT ticket_channel AS canal_nombre
    FROM customer_support_tickets_phase1

    UNION

    SELECT ticket_channel AS canal_nombre
    FROM customer_support_tickets_phase2
) AS unified_channels
WHERE canal_nombre IS NOT NULL
ORDER BY canal_nombre;

INSERT INTO dim_agente (agente_id)
SELECT DISTINCT assigned_agent_id
FROM customer_support_tickets_phase2
WHERE assigned_agent_id IS NOT NULL
ORDER BY assigned_agent_id;

INSERT INTO dim_equipo (equipo_nombre)
SELECT DISTINCT assigned_team
FROM customer_support_tickets_phase2
WHERE assigned_team IS NOT NULL
ORDER BY assigned_team;

-- ============================================================
-- 3. PHASE 1 FACT TABLE
-- Grain: one row per ticket
-- ============================================================

CREATE TABLE fact_tickets_fase1 (
    ticket_id INT PRIMARY KEY,
    fase_key INT NOT NULL,
    asunto_key INT NOT NULL,
    producto_key INT NOT NULL,
    canal_key INT NOT NULL,
    date_of_purchase DATE NULL,
    ticket_type VARCHAR(50) NOT NULL,
    ticket_status VARCHAR(50) NOT NULL,
    ticket_priority VARCHAR(20) NOT NULL,
    first_response_time DATETIME NULL,
    time_to_resolution DATETIME NULL,
    duracion_valida_flag TINYINT NULL,
    response_to_resolution_minutes INT NULL,
    customer_satisfaction_rating DECIMAL(3, 1) NULL,

    CONSTRAINT fk_f1_fase
        FOREIGN KEY (fase_key) REFERENCES dim_fase(fase_key),
    CONSTRAINT fk_f1_asunto
        FOREIGN KEY (asunto_key) REFERENCES dim_asunto(asunto_key),
    CONSTRAINT fk_f1_producto
        FOREIGN KEY (producto_key) REFERENCES dim_producto(producto_key),
    CONSTRAINT fk_f1_canal
        FOREIGN KEY (canal_key) REFERENCES dim_canal(canal_key),
    CONSTRAINT chk_f1_duracion_valida
        CHECK (duracion_valida_flag IS NULL OR duracion_valida_flag IN (0, 1))
);

INSERT INTO fact_tickets_fase1 (
    ticket_id,
    fase_key,
    asunto_key,
    producto_key,
    canal_key,
    date_of_purchase,
    ticket_type,
    ticket_status,
    ticket_priority,
    first_response_time,
    time_to_resolution,
    duracion_valida_flag,
    response_to_resolution_minutes,
    customer_satisfaction_rating
)
SELECT
    source.ticket_id,
    phase.fase_key,
    subject.asunto_key,
    product.producto_key,
    channel.canal_key,
    source.date_of_purchase,
    source.ticket_type,
    source.ticket_status,
    source.ticket_priority,
    source.first_response_time,
    source.time_to_resolution,
    CASE
        WHEN source.ticket_status <> 'Closed' THEN NULL
        WHEN source.first_response_time IS NOT NULL
         AND source.time_to_resolution IS NOT NULL
         AND source.time_to_resolution >= source.first_response_time
            THEN 1
        ELSE 0
    END,
    CASE
        WHEN source.ticket_status = 'Closed'
         AND source.first_response_time IS NOT NULL
         AND source.time_to_resolution IS NOT NULL
         AND source.time_to_resolution >= source.first_response_time
        THEN TIMESTAMPDIFF(
            MINUTE,
            source.first_response_time,
            source.time_to_resolution
        )
    END,
    source.customer_satisfaction_rating
FROM customer_support_tickets_phase1 AS source
JOIN dim_fase AS phase
    ON phase.fase_nombre = 'Fase 1'
JOIN dim_asunto AS subject
    ON subject.asunto_nombre = source.ticket_subject
JOIN dim_producto AS product
    ON product.producto_nombre = source.product_purchased
JOIN dim_canal AS channel
    ON channel.canal_nombre = source.ticket_channel;

-- ============================================================
-- 4. PHASE 2 FACT TABLE
-- Grain: one row per ticket
-- ============================================================

CREATE TABLE fact_tickets_fase2 (
    ticket_id INT PRIMARY KEY,
    fase_key INT NOT NULL,
    fecha_creacion_key INT NOT NULL,
    asunto_key INT NOT NULL,
    producto_key INT NOT NULL,
    canal_key INT NOT NULL,
    agente_key INT NOT NULL,
    equipo_key INT NOT NULL,
    ticket_type VARCHAR(100) NOT NULL,
    ticket_status VARCHAR(50) NOT NULL,
    ticket_priority VARCHAR(30) NOT NULL,
    ticket_created_at DATETIME NOT NULL,
    first_response_at DATETIME NULL,
    resolved_at DATETIME NULL,
    escalated_flag TINYINT NOT NULL,
    escalation_level VARCHAR(30) NULL,
    resolved_by_level VARCHAR(30) NOT NULL,
    first_response_minutes INT NULL,
    resolution_minutes INT NULL,
    agent_handling_minutes INT NOT NULL,
    customer_satisfaction_rating TINYINT NULL,

    CONSTRAINT fk_f2_fase
        FOREIGN KEY (fase_key) REFERENCES dim_fase(fase_key),
    CONSTRAINT fk_f2_fecha
        FOREIGN KEY (fecha_creacion_key) REFERENCES dim_fecha(fecha_key),
    CONSTRAINT fk_f2_asunto
        FOREIGN KEY (asunto_key) REFERENCES dim_asunto(asunto_key),
    CONSTRAINT fk_f2_producto
        FOREIGN KEY (producto_key) REFERENCES dim_producto(producto_key),
    CONSTRAINT fk_f2_canal
        FOREIGN KEY (canal_key) REFERENCES dim_canal(canal_key),
    CONSTRAINT fk_f2_agente
        FOREIGN KEY (agente_key) REFERENCES dim_agente(agente_key),
    CONSTRAINT fk_f2_equipo
        FOREIGN KEY (equipo_key) REFERENCES dim_equipo(equipo_key)
);

INSERT INTO fact_tickets_fase2 (
    ticket_id,
    fase_key,
    fecha_creacion_key,
    asunto_key,
    producto_key,
    canal_key,
    agente_key,
    equipo_key,
    ticket_type,
    ticket_status,
    ticket_priority,
    ticket_created_at,
    first_response_at,
    resolved_at,
    escalated_flag,
    escalation_level,
    resolved_by_level,
    first_response_minutes,
    resolution_minutes,
    agent_handling_minutes,
    customer_satisfaction_rating
)
SELECT
    source.ticket_id,
    phase.fase_key,
    date_dim.fecha_key,
    subject.asunto_key,
    product.producto_key,
    channel.canal_key,
    agent.agente_key,
    team.equipo_key,
    source.ticket_type,
    source.ticket_status,
    source.ticket_priority,
    source.ticket_created_at,
    source.first_response_at,
    source.resolved_at,
    source.escalated_flag,
    source.escalation_level,
    source.resolved_by_level,
    CASE
        WHEN source.first_response_at IS NOT NULL
         AND source.first_response_at >= source.ticket_created_at
        THEN TIMESTAMPDIFF(
            MINUTE,
            source.ticket_created_at,
            source.first_response_at
        )
    END,
    CASE
        WHEN source.ticket_status = 'Closed'
         AND source.resolved_at IS NOT NULL
         AND source.resolved_at >= source.ticket_created_at
        THEN TIMESTAMPDIFF(
            MINUTE,
            source.ticket_created_at,
            source.resolved_at
        )
    END,
    source.agent_handling_minutes,
    source.customer_satisfaction_rating
FROM customer_support_tickets_phase2 AS source
JOIN dim_fase AS phase
    ON phase.fase_nombre = 'Fase 2'
JOIN dim_fecha AS date_dim
    ON date_dim.fecha = DATE(source.ticket_created_at)
JOIN dim_asunto AS subject
    ON subject.asunto_nombre = source.ticket_subject
JOIN dim_producto AS product
    ON product.producto_nombre = source.product_purchased
JOIN dim_canal AS channel
    ON channel.canal_nombre = source.ticket_channel
JOIN dim_agente AS agent
    ON agent.agente_id = source.assigned_agent_id
JOIN dim_equipo AS team
    ON team.equipo_nombre = source.assigned_team;
