# RADAR Backend Docker Setup

This Docker setup allows you to run the RADAR Backend application in a containerized environment.

## Files Created

- `Dockerfile` - Main application container definition
- `docker-compose.yml` - Multi-service orchestration with Elasticsearch
- `requirements.txt` - Python dependencies
- `.dockerignore` - Files to exclude from Docker build context
- `.env.template` - Environment variables template

## Quick Start

### 1. Configure Environment Variables

Copy the environment template and fill in your values:
```bash
cp .env.template .env
# Edit .env with your actual configuration values
```

### 2. Build and Run with Docker Compose

```bash
# Start all services (app + Elasticsearch)
docker-compose up -d

# View logs
docker-compose logs -f sap-elastic

# Stop services
docker-compose down
```

### 3. Build and Run with Docker Only

```bash
# Build the image
docker build -t sap-elastic-app .

# Run the container
docker run -d \
  --name sap-elastic \
  --env-file .env \
  -v $(pwd)/logs:/app/logs \
  sap-elastic-app
```

## Environment Variables

Required environment variables (set in `.env` file):

- `ELASTIC_HOST` - Elasticsearch host URL
- `ELASTIC_USERNAME` - Elasticsearch username
- `ELASTIC_PASSWORD` - Elasticsearch password
- `SAP_HANA_HOST` - SAP HANA server host
- `SAP_HANA_PORT` - SAP HANA server port (default: 30015)
- `SAP_HANA_USER` - SAP HANA username
- `SAP_HANA_PASSWORD` - SAP HANA password
- `SAP_DATABASE` - SAP HANA database name
- `SAP_HANA_MASTER_QUERY` - Master query to execute

Optional environment variables:

- `APP_NAME` - Application name (default: "RADAR Backend")
- `ENVIRONMENT` - Environment (default: "PRODUCTION")
- `LOG_LEVEL` - Logging level (default: "INFO")

## Docker Features

### Security
- Minimal base image (Python 3.12-alpine)
- Only essential system dependencies installed

### Optimization
- Multi-stage build process for smaller image size
- Docker layer caching for faster builds
- .dockerignore to exclude unnecessary files

### Monitoring
- Health check endpoint
- Structured logging with timestamps
- Log persistence via volume mount

## Volumes

- `./logs:/app/logs` - Application logs persistence

## Troubleshooting

### Restart Services
```bash
docker-compose restart
```

## Production Considerations

1. **Security**: Change default passwords in `.env` file
2. **Monitoring**: Consider adding monitoring tools like Prometheus/Grafana
3. **Backups**: Implement backup strategy for Elasticsearch data
4. **Resources**: Adjust memory limits based on your data volume
5. **Networking**: Configure proper firewall rules for production deployment
