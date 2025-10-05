-- Create restricted user for N8N_EXECUTION database
-- This migration runs once to create the DML-only user
-- Note: Database is created by init-data.sh during postgres initialization

-- Create user if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${POSTGRES_N8N_EXECUTION_USER}') THEN
        CREATE USER "${POSTGRES_N8N_EXECUTION_USER}" WITH PASSWORD '${POSTGRES_N8N_EXECUTION_PASSWORD}';
    END IF;
END
$$;

-- Grant connection privileges
GRANT CONNECT ON DATABASE ${POSTGRES_N8N_EXECUTION_DB} TO "${POSTGRES_N8N_EXECUTION_USER}";