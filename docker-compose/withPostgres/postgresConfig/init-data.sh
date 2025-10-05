#!/bin/bash
set -e;


if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE USER "${POSTGRES_NON_ROOT_USER}" WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
		GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO "${POSTGRES_NON_ROOT_USER}";
		GRANT CREATE ON SCHEMA public TO "${POSTGRES_NON_ROOT_USER}";
	EOSQL
else
	echo "SETUP INFO: No Environment variables given!"
fi

# Create N8N_EXECUTION database with Flyway admin user
if [ -n "${POSTGRES_N8N_EXECUTION_DB:-}" ] && [ -n "${POSTGRES_N8N_EXECUTION_FLYWAY_USER:-}" ] && [ -n "${POSTGRES_N8N_EXECUTION_FLYWAY_PASSWORD:-}" ]; then
	echo "SETUP INFO: Creating ${POSTGRES_N8N_EXECUTION_DB} database and Flyway admin user..."

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
      CREATE USER "${POSTGRES_N8N_EXECUTION_FLYWAY_USER}" WITH PASSWORD '${POSTGRES_N8N_EXECUTION_FLYWAY_PASSWORD}';

      CREATE DATABASE ${POSTGRES_N8N_EXECUTION_DB}
          WITH OWNER = "${POSTGRES_N8N_EXECUTION_FLYWAY_USER}";
  EOSQL

	echo "SETUP INFO: ${POSTGRES_N8N_EXECUTION_DB} database and Flyway admin user setup complete."
else
	echo "SETUP INFO: N8N_EXECUTION database environment variables not set, skipping database creation."
fi
