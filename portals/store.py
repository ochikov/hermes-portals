"""Transactional artifact state shared by Hermes and the browser companion.

SQLite is also the process boundary: the agent can edit a diagram without
knowing browser credentials or holding a web server in its own event loop.
Only hashes of Portals-issued pairing/session tokens are persisted.
"""
from __future__ import annotations

import hashlib
import json
import re
import secrets
import sqlite3
import time
import uuid
from contextlib import contextmanager
from pathlib import Path

from .artifacts import MAX_ARTIFACTS, template, update_artifact, validate_artifact


class Conflict(Exception):
    pass


class AccessDenied(Exception):
    pass


def digest(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def demo() -> dict:
    return {
        "id": str(uuid.uuid4()), "title": "A resilient service", "revision": 1,
        "kind": "diagram", "schema_version": 1,
        "nodes": [
            {"id": "client", "label": "Client", "x": .10, "y": .50},
            {"id": "gateway", "label": "Gateway", "x": .32, "y": .50},
            {"id": "a", "label": "Server A", "x": .57, "y": .25},
            {"id": "b", "label": "Server B", "x": .57, "y": .75},
            {"id": "data", "label": "Database", "x": .86, "y": .50},
        ],
        "edges": [["client", "gateway"], ["gateway", "a"], ["gateway", "b"],
                  ["a", "data"], ["b", "data"]],
        "source": "client", "sink": "data", "disabled": [],
        "selected": "a", "display": "laptop",
    }


def validate_graph(value: dict) -> dict:
    if not isinstance(value, dict):
        raise ValueError("Diagram must be an object")
    nodes, edges = value.get("nodes"), value.get("edges")
    if not isinstance(nodes, list) or not 2 <= len(nodes) <= 12:
        raise ValueError("Use 2–12 nodes")
    if not isinstance(edges, list) or not 1 <= len(edges) <= 30:
        raise ValueError("Use 1–30 edges")
    title = value.get("title", "Untitled diagram")
    if not isinstance(title, str) or not 1 <= len(title) <= 80:
        raise ValueError("Title must be 1–80 characters")
    clean = []
    for node in nodes:
        if not isinstance(node, dict):
            raise ValueError("Invalid node")
        ident, label = node.get("id"), node.get("label")
        if not isinstance(ident, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,32}", ident):
            raise ValueError("Node IDs must use letters, digits, hyphens or underscores")
        if not isinstance(label, str) or not 1 <= len(label) <= 32:
            raise ValueError("Node labels must be 1–32 characters")
        for axis in ("x", "y"):
            n = node.get(axis)
            if type(n) not in (float, int) or not .08 <= n <= .92:
                raise ValueError("Node x/y positions must be between 0.08 and 0.92")
        clean.append({k: node[k] for k in ("id", "label", "x", "y")})
    ids = {n["id"] for n in clean}
    if len(ids) != len(clean):
        raise ValueError("Node IDs must be unique")
    clean_edges = []
    for edge in edges:
        if not isinstance(edge, list) or len(edge) != 2 or any(not isinstance(n, str) or n not in ids for n in edge):
            raise ValueError("Edges must connect existing nodes")
        if edge[0] == edge[1] or edge in clean_edges:
            raise ValueError("Duplicate edges and self-links are unsupported")
        clean_edges.append(edge)
    if any(not isinstance(value.get(key), str) or value[key] not in ids for key in ("source", "sink")):
        raise ValueError("source and sink must identify existing nodes")
    return {"title": title, "nodes": clean, "edges": clean_edges,
            "source": value["source"], "sink": value["sink"]}


class Store:
    def __init__(self, directory: Path):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.path = self.directory / "portals.sqlite3"
        with self.connection() as db:
            db.execute("PRAGMA journal_mode=WAL")
            db.executescript("""
                CREATE TABLE IF NOT EXISTS artifact(id INTEGER PRIMARY KEY CHECK(id=1), body TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS library(id TEXT PRIMARY KEY, body TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS tokens(hash TEXT PRIMARY KEY, kind TEXT NOT NULL, expires REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY, role TEXT NOT NULL, name TEXT NOT NULL,
                    expires REAL NOT NULL, seen REAL NOT NULL);
            """)
            db.execute("INSERT OR IGNORE INTO artifact VALUES(1, ?)", (json.dumps(demo()),))
            # Upgrade the original single-diagram room without changing its ID or state.
            obj = json.loads(db.execute("SELECT body FROM artifact WHERE id=1").fetchone()[0])
            if "kind" not in obj:
                obj.update(kind="diagram", schema_version=1)
                db.execute("UPDATE artifact SET body=? WHERE id=1", (json.dumps(obj),))
            db.execute("INSERT OR IGNORE INTO library VALUES(?, ?)", (obj["id"], json.dumps(obj)))
        self.path.chmod(0o600)

    @contextmanager
    def connection(self):
        db = sqlite3.connect(self.path, timeout=5)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def snapshot(self) -> dict:
        with self.connection() as db:
            return json.loads(db.execute("SELECT body FROM artifact WHERE id=1").fetchone()[0])

    def workspace(self) -> dict:
        # One read transaction keeps the active tool and library in the same revision.
        with self.connection() as db:
            db.execute("BEGIN")
            active = json.loads(db.execute("SELECT body FROM artifact WHERE id=1").fetchone()[0])
            entries = [json.loads(row[0]) for row in db.execute("SELECT body FROM library ORDER BY rowid")]
            return {"artifact": active, "library": [
                {key: obj[key] for key in ("id", "kind", "title")} for obj in entries]}

    def mutate(self, action: dict, revision: int | None = None, *, owner: bool = True) -> dict:
        with self.connection() as db:
            db.execute("BEGIN IMMEDIATE")
            obj = json.loads(db.execute("SELECT body FROM artifact WHERE id=1").fetchone()[0])
            if revision is not None and obj["revision"] != revision:
                raise Conflict("Workspace changed. Review the current state and try again.")
            kind = action.get("type")
            revision_before = obj["revision"]
            if kind in ("show", "create", "template"):
                if not owner:
                    raise AccessDenied("Only the owner can create tools")
                if db.execute("SELECT COUNT(*) FROM library").fetchone()[0] >= MAX_ARTIFACTS:
                    raise ValueError(f"This prototype supports up to {MAX_ARTIFACTS} saved tools")
                value = action.get("artifact")
                if kind == "show":
                    graph = action.get("diagram")
                    if not isinstance(graph, dict):
                        raise ValueError("Diagram must be an object")
                    value = {**graph, "kind": "diagram"}
                elif kind == "template":
                    value = template(action.get("template"))
                obj = {**validate_artifact(value), "id": str(uuid.uuid4()), "display": "laptop"}
            elif kind == "open":
                if not owner:
                    raise AccessDenied("Only the owner can switch the active tool")
                ident = action.get("artifact_id")
                if not isinstance(ident, str):
                    raise ValueError("Choose a saved tool ID from the library")
                row = db.execute("SELECT body FROM library WHERE id=?", (ident,)).fetchone()
                if not row:
                    raise ValueError("Tool not found in this workspace")
                obj = json.loads(row[0])
                obj["display"] = "laptop"
            elif kind in ("set_node", "select"):
                if obj["kind"] != "diagram":
                    raise ValueError("Open a diagram before changing nodes")
                node = action.get("node")
                if node not in {n["id"] for n in obj["nodes"]}:
                    raise ValueError("Unknown node")
                if kind == "select":
                    obj["selected"] = node
                else:
                    enabled = action.get("enabled")
                    if type(enabled) is not bool:
                        raise ValueError("enabled must be true or false")
                    off = set(obj["disabled"])
                    off.discard(node) if enabled else off.add(node)
                    obj["disabled"] = sorted(off)
            elif kind == "handoff":
                target = action.get("target")
                if target not in ("laptop", "phone"):
                    raise ValueError("Choose laptop or phone")
                if target == "phone" and not db.execute(
                    "SELECT 1 FROM sessions WHERE role='phone' AND expires>? AND seen>?",
                    (time.time(), time.time() - 12),
                ).fetchone():
                    raise ValueError("Connect the paired phone before transferring")
                obj["display"] = target
            elif kind == "restore":
                if obj["kind"] != "diagram":
                    raise ValueError("Open a diagram before restoring nodes")
                obj["disabled"] = []
            elif kind in ("set_item", "set_value", "set_values"):
                update_artifact(obj, action)
            else:
                raise ValueError("Unknown action")
            obj["revision"] = revision_before + 1
            db.execute("UPDATE artifact SET body=? WHERE id=1", (json.dumps(obj),))
            db.execute("INSERT INTO library VALUES(?, ?) ON CONFLICT(id) DO UPDATE SET body=excluded.body",
                       (obj["id"], json.dumps(obj)))
            return obj

    def invitation(self, kind: str) -> str:
        if kind not in ("owner", "phone"):
            raise ValueError("Unknown invitation kind")
        token = secrets.token_urlsafe(32)
        with self.connection() as db:
            db.execute("DELETE FROM tokens WHERE kind=? OR expires<?", (kind, time.time()))
            db.execute("INSERT INTO tokens VALUES(?,?,?)", (digest(token), kind, time.time() + 120))
        return token

    def redeem(self, token: str, kind: str, name: str) -> str:
        if not isinstance(token, str) or len(token) > 128 or kind not in ("owner", "phone"):
            raise AccessDenied("Invalid invitation")
        with self.connection() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT * FROM tokens WHERE hash=?", (digest(token),)).fetchone()
            if not row or row["expires"] < time.time() or row["kind"] != kind:
                raise AccessDenied("Invitation expired or already used. Create a new QR code.")
            db.execute("DELETE FROM tokens WHERE hash=?", (digest(token),))
            # One laptop owner session and one paired phone for this prototype.
            db.execute("DELETE FROM sessions WHERE role=? OR expires<?", (kind, time.time()))
            session = secrets.token_urlsafe(32)
            db.execute("INSERT INTO sessions VALUES(?,?,?,?,?)",
                       (digest(session), kind, name[:40], time.time() + 8 * 3600, time.time()))
            return session

    def session(self, token: str | None, *, touch: bool = False) -> dict:
        if not token:
            raise AccessDenied("Open the laptop invitation or scan a fresh QR code")
        hashed = digest(token)
        with self.connection() as db:
            row = db.execute("SELECT * FROM sessions WHERE hash=? AND expires>?", (hashed, time.time())).fetchone()
            if not row:
                raise AccessDenied("Session expired or revoked. Pair again.")
            if touch:
                db.execute("UPDATE sessions SET seen=? WHERE hash=?", (time.time(), hashed))
            return {"role": row["role"], "name": row["name"]}

    def phone(self) -> dict:
        with self.connection() as db:
            row = db.execute("SELECT hash,name,seen FROM sessions WHERE role='phone' AND expires>?", (time.time(),)).fetchone()
        return {"paired": bool(row), "online": bool(row and row["seen"] > time.time() - 12),
                "name": row["name"] if row else None, "id": row["hash"][:12] if row else None}

    def revoke_phone(self):
        with self.connection() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("DELETE FROM sessions WHERE role='phone'")
            db.execute("DELETE FROM tokens WHERE kind='phone'")
            obj = json.loads(db.execute("SELECT body FROM artifact WHERE id=1").fetchone()[0])
            obj["display"] = "laptop"
            obj["revision"] += 1
            db.execute("UPDATE artifact SET body=? WHERE id=1", (json.dumps(obj),))

    def reset_access(self):
        """Fresh authorization after a server restart; preserve diagram content."""
        with self.connection() as db:
            db.execute("DELETE FROM sessions")
            db.execute("DELETE FROM tokens")
        self.revoke_phone()
