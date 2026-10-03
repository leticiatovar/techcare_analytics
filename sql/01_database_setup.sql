/*
TechCare - Database Setup
File: 01_database_setup.sql
Purpose: create the Phase 1 and Phase 2 source tables.
Engine: MySQL 8.x

Execution order:
1. Run this script against a new schema.
2. Load the CSV files prepared by the Python notebooks.
3. Run 02_dimensional_model.sql.

This script defines the table structure. LOAD DATA LOCAL INFILE is not
included because file paths depend on the local environment.
*/

CREATE DATABASE IF NOT EXISTS techcare_customer_support
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE techcare_customer_support;

-- ============================================================
-- PHASE 1
-- Public sample of support tickets
-- ============================================================

CREATE TABLE customer_support_tickets_phase1 (
    ticket_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    customer_email VARCHAR(150),
    customer_age INT,
    customer_gender VARCHAR(20),
    product_purchased VARCHAR(100),
    date_of_purchase DATE,
    ticket_type VARCHAR(50),
    ticket_subject VARCHAR(100),
    ticket_description TEXT,
    ticket_status VARCHAR(50),
    resolution TEXT,
    ticket_priority VARCHAR(20),
    ticket_channel VARCHAR(50),
    first_response_time DATETIME NULL,
    time_to_resolution DATETIME NULL,
    customer_satisfaction_rating DECIMAL(3, 1) NULL,

    CONSTRAINT chk_f1_customer_age
        CHECK (customer_age IS NULL OR customer_age BETWEEN 0 AND 120),
    CONSTRAINT chk_f1_satisfaction
        CHECK (
            customer_satisfaction_rating IS NULL
            OR customer_satisfaction_rating BETWEEN 1 AND 5
        )
);

-- ============================================================
-- PHASE 2
-- Six-month synthetic dataset for methodological validation
-- ============================================================

CREATE TABLE customer_support_tickets_phase2 (
    ticket_id INT PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    customer_age INT NOT NULL,
    customer_gender VARCHAR(30) NOT NULL,
    product_purchased VARCHAR(150) NOT NULL,
    ticket_created_at DATETIME NOT NULL,
    first_response_at DATETIME NULL,
    resolved_at DATETIME NULL,
    ticket_type VARCHAR(100) NOT NULL,
    ticket_subject VARCHAR(150) NOT NULL,
    ticket_description TEXT NOT NULL,
    ticket_status VARCHAR(50) NOT NULL,
    resolution TEXT NULL,
    ticket_priority VARCHAR(30) NOT NULL,
    priority_rule VARCHAR(100) NOT NULL,
    ticket_channel VARCHAR(30) NOT NULL,
    assigned_team VARCHAR(100) NOT NULL,
    assigned_agent_id VARCHAR(50) NOT NULL,
    escalated_flag TINYINT NOT NULL,
    escalation_level VARCHAR(30) NULL,
    resolved_by_level VARCHAR(30) NOT NULL,
    agent_handling_minutes INT NOT NULL,
    customer_satisfaction_rating TINYINT NULL,

    CONSTRAINT chk_f2_customer_age
        CHECK (customer_age BETWEEN 0 AND 120),
    CONSTRAINT chk_f2_escalated_flag
        CHECK (escalated_flag IN (0, 1)),
    CONSTRAINT chk_f2_handling_minutes
        CHECK (agent_handling_minutes >= 0),
    CONSTRAINT chk_f2_satisfaction
        CHECK (
            customer_satisfaction_rating IS NULL
            OR customer_satisfaction_rating BETWEEN 1 AND 5
        )
);

-- After creating the tables, load:
-- - customer_support_tickets_mysql.csv into customer_support_tickets_phase1
-- - phase2_support_tickets_mysql.csv into customer_support_tickets_phase2
