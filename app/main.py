from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import prices

app = FastAPI(title="EGX Analytics API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(prices.router, prefix="/api/v1/prices", tags=["prices"])

@app.get("/")
async def root():
    return {"message": "EGX Analytics API is running"}
