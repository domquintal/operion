import time
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Literal, Optional
from . import store
from .flows.finance_reconcile import run as run_reconcile
from .flows.hr_onboarding import run as run_onboarding
from .flows.data_sync import run as run_datasync

app = FastAPI(title="Operion API", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"],)

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

class RunRequest(BaseModel):
    flow: str

@app.on_event("startup")
def boot():
    store.add_sample_runs_if_empty()

@app.get("/health")
def health(): return {"status": "ok"}

@app.get("/runs", response_model=List[Run])
def runs(): return store.list_runs()

@app.post("/heartbeat")
def heartbeat(hb: Heartbeat):
    return {"ok": True, "record": store.upsert_heartbeat(hb.agent_id, hb.status)}

@app.get("/heartbeats")
def heartbeats(): return store.get_heartbeats()

@app.post("/run")
def run_flow(req: RunRequest):
    flow = req.flow.strip().lower()
    base = Path(__file__).resolve().parents[2]
    now = int(time.time())
    if flow == "finance.reconcile":
        summary = run_reconcile(str(base / "agent" / "data" / "invoices" / "in"),
                                str(base / "agent" / "data" / "invoices" / "processed"),
                                str(base / "policies" / "accounting.yaml"))
        rid=f"r-{now}"; store.append_run({"id":rid,"flow":flow,"status":"succeeded","ts":now,"items":summary.get("total",0)})
        return {"ok": True, "run_id": rid, "summary": summary}
    if flow == "hr.onboarding":
        summary = run_onboarding(str(base / "agent" / "data" / "hr" / "in"),
                                 str(base / "agent" / "data" / "hr" / "processed"),
                                 str(base / "policies" / "hr.yaml"))
        rid=f"r-{now}"; store.append_run({"id":rid,"flow":flow,"status":"succeeded","ts":now,"items":summary.get("total",0)})
        return {"ok": True, "run_id": rid, "summary": summary}
    if flow == "data.sync":
        summary = run_datasync()
        rid=f"r-{now}"; store.append_run({"id":rid,"flow":flow,"status":"succeeded","ts":now,"items":summary.get("total",0)})
        return {"ok": True, "run_id": rid, "summary": summary}
    raise HTTPException(status_code=400, detail="unknown flow")
