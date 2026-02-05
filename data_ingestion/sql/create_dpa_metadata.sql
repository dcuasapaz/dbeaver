-- Script SQL para crear la tabla de metadata
-- Se ejecuta con: psql -U $DB_USER -d $DB_NAME -f create_dpa_metadata.sql

CREATE TABLE IF NOT EXISTS dpa.dpa_metadata (
    table_name TEXT,
    version TEXT,
    load_date TIMESTAMP,
    source_file TEXT
);