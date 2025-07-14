import os

APP_NAME = os.getenv("APP_NAME", "Elastic Search <-> SAP Integration")

# Parametri vari
ENVIRONMENT = os.getenv("ENVIRONMENT", "DEV")
LOG_LEVEL = os.getenv("LOG_LEVEL", "DEBUG")

ELASTIC_HOST = os.getenv("ELASTIC_HOST", "https://localhost:9200")
ELASTIC_USERNAME = os.getenv("ELASTIC_USERNAME", None)
ELASTIC_PASSWORD = os.getenv("ELASTIC_PASSWORD", None)

if ELASTIC_USERNAME is None or ELASTIC_PASSWORD is None:
    raise ValueError("Please set both ELASTIC_USERNAME and ELASTIC_PASSWORD in your environment variables.")


SAP_HANA_HOST = os.getenv("SAP_HANA_HOST", None)
SAP_HANA_PORT = os.getenv("SAP_HANA_PORT", None)
SAP_HANA_USER = os.getenv("SAP_HANA_USER", None)
SAP_HANA_PASSWORD = os.getenv("SAP_HANA_PASSWORD", None)
SAP_DATABASE = os.getenv("SAP_DATABASE", None)
SAP_HANA_MASTER_QUERY = os.getenv("SAP_HANA_MASTER_QUERY", "SELECT * FROM \"@KAIROS_RADAR\"")