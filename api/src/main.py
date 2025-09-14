from fastapi import FastAPI, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Literal, Optional
from . import store

app = FastAPI(title="Operion API", version="0.1.0")

# Allow local file / dev servers to call us
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*",],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class Run(BaseModel):
    id: str
    flow: str
    status: Literal["succeeded","failed","running"]
    ts: int
    items: Optional[int] = None
    error: Optional[str] = None

class Heartbeat(BaseModel):
    agent_id: str
    status: Literal["ok","warn","down"] = "ok"

@app.on_event("startup")
def boot():
    store.add_sample_runs_if_empty()

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/runs", response_model=List[Run])
def runs():
    return store.list_runs()

@app.post("/heartbeat")
def heartbeat(hb: Heartbeat):
    rec = store.upsert_heartbeat(hb.agent_id, hb.status)
    return {"ok": True, "record": rec}

@app.get("/heartbeats")
def heartbeats():
    return store.get_heartbeats()
