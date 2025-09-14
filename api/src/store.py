import json, os, time
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
RUNS_FILE = os.path.join(DATA_DIR, "runs.json")
HEARTBEATS_FILE = os.path.join(DATA_DIR, "heartbeats.json")

def _read(p, default):
    try:
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default

def _write(p, obj):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
    os.replace(tmp, p)

def list_runs():
    return _read(RUNS_FILE, [])

def add_sample_runs_if_empty():
    runs = _read(RUNS_FILE, [])
    if not runs:
        now = int(time.time())
        seed = [
            {"id":"r-001","flow":"hr.onboarding","status":"succeeded","ts":now-3600,"items":5},
            {"id":"r-002","flow":"finance.reconcile","status":"succeeded","ts":now-1800,"items":248},
            {"id":"r-003","flow":"data.sync","status":"failed","ts":now-600,"items":120,"error":"missing vendor id"},
        ]
        _write(RUNS_FILE, seed)

def append_run(run):
    runs = _read(RUNS_FILE, [])
    runs.append(run)
    _write(RUNS_FILE, runs)
    return run

def upsert_heartbeat(agent_id:str, status:str="ok"):
    hb = _read(HEARTBEATS_FILE, {})
    hb[agent_id] = {"status": status, "ts": int(time.time())}
    _write(HEARTBEATS_FILE, hb)
    return hb[agent_id]

def get_heartbeats():
    return _read(HEARTBEATS_FILE, {})
