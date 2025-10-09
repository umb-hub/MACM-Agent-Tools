#!/usr/bin/env python3
"""
MACM Agent Tools API Server
FastAPI server implementing the endpoints defined in actions.yaml
"""

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
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

# Privacy policy endpoint
@app.get("/privacy", include_in_schema=False, response_class=HTMLResponse)
async def privacy_policy():
    """Privacy policy page"""
    # Get the path to the privacy template (now in src/templates)
    template_path = os.path.join(os.path.dirname(__file__), "templates", "privacy.html")
    
    try:
        with open(template_path, "r", encoding="utf-8") as file:
            html_content = file.read()
        return HTMLResponse(content=html_content, status_code=200)
    except FileNotFoundError:
        return HTMLResponse(
            content="<h1>Privacy Policy</h1><p>Privacy policy not found.</p>",
            status_code=404
        )

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
            "health": "/api/health",
            "privacy": "/privacy"
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