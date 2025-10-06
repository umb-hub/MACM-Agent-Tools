# Docker Setup for MACM Agent Tools API

This directory contains Docker configuration files to run the MACM Agent Tools API server in containers.

## Files

- `Dockerfile` - Main Docker image definition
- `docker-compose.yml` - Production deployment configuration
- `docker-compose.dev.yml` - Development configuration with hot reload
- `.dockerignore` - Files to exclude from Docker build context

## Quick Start

### Production Mode

```bash
# Build and start the API server
docker-compose up -d

# View logs
docker-compose logs -f macm-api

# Stop the service
docker-compose down
```

### Development Mode

```bash
# Build and start with hot reload for development
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f macm-api-dev

# Stop the service
docker-compose -f docker-compose.dev.yml down
```

## API Access

Once running, the API will be available at:
- **Base URL**: http://localhost:8080
- **API Documentation**: http://localhost:8080/docs
- **OpenAPI Spec**: http://localhost:8080/openapi.json
- **Health Check**: http://localhost:8080/api/health

## Key Endpoints

- `GET /api/catalogs/asset_types` - Asset types from CSV
- `GET /api/catalogs/relationships` - Relationship types
- `GET /api/catalogs/protocols` - Network protocols
- `GET /api/catalogs/relationship_pattern` - Relationship patterns
- `POST /api/catalogs/labels` - Assign labels to nodes
- `POST /api/checkers/syntax` - Validate syntax
- `POST /api/checkers/semantic` - Validate semantics
- `GET /api/catalogs/info` - Catalog files information

## Configuration

### Environment Variables

- `PYTHONPATH=/app/src` - Python module path
- `PYTHONDONTWRITEBYTECODE=1` - Disable .pyc files
- `PYTHONUNBUFFERED=1` - Real-time logging

### Volumes

**Production mode:**
- `./catalogs:/app/catalogs:ro` - Mount catalog CSV files (read-only)

**Development mode:**
- `./src:/app/src:ro` - Mount source code for hot reload
- `./catalogs:/app/catalogs:ro` - Mount catalog CSV files

### Ports

- `8080:8080` - API server port

## Docker Commands

### Build only
```bash
docker build -t macm-agent-tools-api .
```

### Run without docker-compose
```bash
docker run -d \
  --name macm-api \
  -p 8080:8080 \
  -v $(pwd)/catalogs:/app/catalogs:ro \
  macm-agent-tools-api
```

### Health Check
```bash
# Check if container is healthy
docker-compose ps

# Manual health check
curl http://localhost:8080/api/health
```

### Debugging

```bash
# Access container shell
docker-compose exec macm-api bash

# View container logs
docker-compose logs -f macm-api

# Restart service
docker-compose restart macm-api
```

## Catalog Files

The container mounts the `./catalogs` directory to provide access to:
- `asset_types.csv`
- `relationships.csv` 
- `protocols.csv`
- `relationship_patterns.csv`

Changes to these files will be reflected in the API responses without requiring container restart.

## Troubleshooting

### Container won't start
1. Check logs: `docker-compose logs macm-api`
2. Verify CSV files exist in `./catalogs/`
3. Check port 8080 is not in use: `lsof -i :8080`

### CSV parsing errors
1. Verify CSV file formats match expected structure
2. Check for proper semicolon/comma delimiters
3. Review logs for specific error messages

### Network issues
1. Ensure port 8080 is available
2. Check firewall settings
3. Verify Docker network: `docker network ls`

## Development

For development with automatic code reloading:

```bash
# Use development compose file
docker-compose -f docker-compose.dev.yml up -d

# This mounts source code and enables uvicorn --reload
```

The development setup provides:
- Hot reload on code changes
- Source code mounted as volume
- Development-friendly uvicorn settings