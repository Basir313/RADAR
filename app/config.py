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

if SAP_HANA_HOST is None or SAP_HANA_PORT is None or SAP_HANA_USER is None or SAP_HANA_PASSWORD is None:
    raise ValueError("Please set SAP_HANA_HOST, SAP_HANA_PORT, SAP_HANA_USER, and SAP_HANA_PASSWORD in your environment variables.")

UPDATE_MODE = os.getenv("UPDATE_MODE", "INCREMENTAL").upper()
if UPDATE_MODE not in ["FULL", "INCREMENTAL"]:
    raise ValueError("UPDATE_MODE must be either 'FULL' or 'INCREMENTAL'. Current value: {}".format(UPDATE_MODE))