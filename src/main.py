#!/usr/bin/env python3
"""
MACM Agent Tools API Server
FastAPI server implementing the endpoints defined in actions.yaml
"""

from fastapi import FastAPI
import uvicorn

from api.catalogs import router as catalogs_router
from api.checkers import router as checkers_router

# Initialize FastAPI app
app = FastAPI(
    title="MACM Agent Tools API",
    description="Multi-purpose Application Composition Model (MACM) API for catalog management and model validation",
    version="1.0.0"
)

# Include API routers
app.include_router(catalogs_router, prefix="/api")
app.include_router(checkers_router, prefix="/api")

# Health check endpoint
@app.get("/api/health")
async def health_check():
    """Basic health check endpoint"""
    return {"status": "healthy", "service": "MACM Agent Tools API"}

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "MACM Agent Tools API",
        "version": "1.0.0",
        "endpoints": {
            "catalogs": "/api/catalogs",
            "checkers": "/api/checkers",
            "health": "/api/health"
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