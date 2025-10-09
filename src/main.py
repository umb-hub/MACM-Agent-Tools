#!/usr/bin/env python3
"""
MACM Agent Tools API Server
FastAPI server implementing the endpoints defined in actions.yaml
"""

from fastapi import FastAPI
import uvicorn
import os

from api.routes.catalogs import router as catalogs_router
from api.routes.checkers import router as checkers_router
from api.routes.cypher import router as cypher_router

# Initialize FastAPI app
app = FastAPI(
    title="MACM Agent Tools API",
    description="Multi-purpose Application Composition Model (MACM) API for catalog management and model validation",
    servers=[{"url": os.getenv("SERVER_URL", "http://localhost:8080")}],
    version="1.0.0"
)

# Include API routers
app.include_router(catalogs_router, prefix="/api")
app.include_router(checkers_router, prefix="/api")
app.include_router(cypher_router, prefix="/api")

# Health check endpoint
@app.get("/api/health", include_in_schema=False)
async def health_check():
    """Basic health check endpoint"""
    return {"status": "healthy", "service": "MACM Agent Tools API"}

# Root endpoint
@app.get("/", include_in_schema=False)
async def root():
    """Root endpoint with API information"""
    return {
        "message": "MACM Agent Tools API",
        "version": "1.0.0",
        "endpoints": {
            "catalogs": "/api/catalogs",
            "checkers": "/api/checkers",
            "cypher": "/api/cypher",
            "health": "/api/health"
        },
        "validation_endpoints": {
            "syntax": "/api/checkers/syntax",
            "semantic": "/api/checkers/semantic", 
            "database": "/api/checkers/database",
            "comprehensive": "/api/checkers/validate-all",
            "test_connection": "/api/checkers/database/test-connection"
        }
    }


if __name__ == "__main__":
    # Run the server
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )