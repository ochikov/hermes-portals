"""Dedicated Portals companion: no Hermes gateway routes or credentials."""
from __future__ import annotations

import argparse
import asyncio
import base64
import fcntl
import io
import ipaddress
import json
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

import qrcode
import qrcode.image.svg
import uvicorn
from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictFloat, StrictInt
from starlette.middleware.trustedhost import TrustedHostMiddleware

from .store import AccessDenied, Conflict, Store
from .mac_control import MacController

ROOT = Path(__file__).resolve().parents[1]


class Exchange(BaseModel):
    model_config = ConfigDict(extra="forbid")
    token: str = Field(min_length=20, max_length=128)
    kind: str = Field(pattern="^(owner|phone)$")
    name: str = Field(default="Phone", min_length=1, max_length=40)


class Action(BaseModel):
    model_config = ConfigDict(extra="forbid")
    type: str = Field(pattern="^(set_node|select|handoff|restore|create|template|open|set_item|set_value|set_values)$")
    revision: StrictInt = Field(ge=1)
    node: str | None = Field(default=None, max_length=32)
    enabled: StrictBool | None = None
    target: str | None = Field(default=None, pattern="^(laptop|phone)$")
    artifact: dict | None = None
    artifact_id: str | None = Field(default=None, max_length=64)
    template: str | None = Field(default=None, pattern="^(diagram|checklist|calculator)$")
    item: str | None = Field(default=None, max_length=32)
    done: StrictBool | None = None
    field: str | None = Field(default=None, max_length=32)
    value: StrictFloat | StrictInt | None = None
    values: dict[str, StrictFloat | StrictInt] | None = Field(default=None, max_length=8)


def create_app(directory: Path, port: int = 8766, lan: str | None = None, *, instance: str = "test") -> FastAPI:
    store = Store(directory)
    public_url = f"http://{lan or '127.0.0.1'}:{port}"
    origins = {f"http://127.0.0.1:{port}", f"http://localhost:{port}", public_url}
    cookie = f"portals_{port}_{instance[:8]}"
    sockets: dict[str, int] = {}
    attempts: dict[str, list[float]] = {}

    @asynccontextmanager
    async def lifespan(app):
        yield

    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None, lifespan=lifespan)
    app.state.store = store
    app.state.mac_control = MacController()
    app.state.cookie = cookie
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=["localhost", "127.0.0.1"] + ([lan] if lan else []))

    @app.middleware("http")
    async def guards(request: Request, call_next):
        if request.method not in ("GET", "HEAD") and request.headers.get("origin") not in origins:
            return JSONResponse({"detail": "Untrusted request origin"}, 403)
        if request.method not in ("GET", "HEAD"):
            # Bound actual bytes, including chunked bodies, before JSON parsing.
            total = 0
            chunks = []
            async for chunk in request.stream():
                total += len(chunk)
                if total > 16384:
                    return JSONResponse({"detail": "Request too large"}, 413)
                chunks.append(chunk)
            request._body = b"".join(chunks)
        response = await call_next(request)
        response.headers.update({
            "Cache-Control": "no-store", "Referrer-Policy": "no-referrer",
            "X-Content-Type-Options": "nosniff", "X-Frame-Options": "DENY",
            "Permissions-Policy": "camera=(self), microphone=(), geolocation=()",
            "Content-Security-Policy": "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; "
                "style-src 'self'; img-src 'self' data:; connect-src 'self'; "
                "worker-src 'self' blob:; media-src 'self' blob:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
        })
        return response

    @app.exception_handler(AccessDenied)
    async def denied(request, error):
        return JSONResponse({"detail": str(error)}, 401)

    @app.exception_handler(Conflict)
    async def conflict(request, error):
        return JSONResponse({"detail": str(error), **store.workspace()}, 409)

    @app.exception_handler(ValueError)
    async def invalid(request, error):
        return JSONResponse({"detail": str(error)}, 400)

    def require(request: Request, owner: bool = False) -> dict:
        who = store.session(request.cookies.get(cookie), touch=True)
        if owner and who["role"] != "owner":
            raise HTTPException(403, "Only the laptop owner can pair or revoke devices")
        return who

    def snapshot(who: dict) -> dict:
        return {**store.workspace(), "phone": store.phone(), "you": who,
                "network": {"lan": bool(lan), "encrypted": False}}

    def require_local_owner(request: Request):
        require(request, owner=True)
        if request.client.host not in ("127.0.0.1", "::1", "testclient") or request.url.hostname not in ("127.0.0.1", "localhost"):
            raise HTTPException(403, "Open Mac control from the laptop's localhost owner page")

    @app.get("/api/mac/status")
    async def mac_status(request: Request):
        require_local_owner(request)
        return app.state.mac_control.status()

    @app.post("/api/mac/open")
    async def mac_open(request: Request):
        require_local_owner(request)
        return await asyncio.to_thread(app.state.mac_control.open)

    @app.post("/api/mac/stop")
    async def mac_stop(request: Request):
        require_local_owner(request)
        return app.state.mac_control.stop()

    @app.get("/api/health")
    async def health():
        return {"service": "hermes-portals", "instance": instance, "version": "0.3.0"}

    @app.post("/api/exchange")
    async def exchange(body: Exchange, request: Request):
        host = request.client.host
        if body.kind == "owner" and host not in ("127.0.0.1", "::1", "testclient"):
            raise HTTPException(403, "Open the owner link on the laptop using localhost")
        now = time.monotonic()
        for key in list(attempts):
            if not attempts[key] or now - attempts[key][-1] > 60:
                del attempts[key]
        if host not in attempts and len(attempts) >= 256:
            raise HTTPException(429, "Try again shortly")
        recent = [t for t in attempts.get(host, []) if now - t < 60]
        if len(recent) >= 10:
            raise HTTPException(429, "Too many pairing attempts. Wait a minute.")
        attempts[host] = recent + [now]
        token = store.redeem(body.token, body.kind, "Laptop" if body.kind == "owner" else body.name)
        response = JSONResponse({"ok": True})
        response.set_cookie(cookie, token, httponly=True, samesite="strict", max_age=8 * 3600)
        return response

    @app.get("/api/state")
    async def state(request: Request):
        return snapshot(require(request))

    @app.post("/api/action")
    async def action(body: Action, request: Request):
        who = require(request, owner=body.type in ("create", "template", "open"))
        store.mutate(body.model_dump(exclude={"revision"}, exclude_none=True), body.revision, owner=who["role"] == "owner")
        return snapshot(who)

    @app.post("/api/pair")
    async def pair(request: Request):
        require(request, owner=True)
        token = store.invitation("phone")
        url = public_url + "/#pair=" + token
        qr = qrcode.make(url, image_factory=qrcode.image.svg.SvgPathImage, box_size=7, border=3)
        output = io.BytesIO()
        qr.save(output)
        return {"url": url, "qr": "data:image/svg+xml;base64," + base64.b64encode(output.getvalue()).decode(),
                "expires_in": 120, "lan": bool(lan)}

    @app.post("/api/revoke")
    async def revoke(request: Request):
        who = require(request, owner=True)
        store.revoke_phone()
        return snapshot(who)

    @app.post("/api/shutdown")
    async def shutdown(request: Request):
        require(request, owner=True)
        if request.client.host not in ("127.0.0.1", "::1", "testclient"):
            raise HTTPException(403, "Stop Portals from the laptop")
        callback = getattr(app.state, "shutdown", None)
        if callback is None:
            raise HTTPException(409, "This server is managed by the test runner")
        asyncio.get_running_loop().call_later(.25, callback)
        return {"ok": True}

    @app.websocket("/ws")
    async def socket(ws: WebSocket):
        if ws.headers.get("origin") not in origins:
            await ws.close(code=4403)
            return
        token = ws.cookies.get(cookie)
        try:
            who = store.session(token, touch=True)
        except AccessDenied:
            await ws.close(code=4401)
            return
        if sockets.get(token, 0) >= 4:
            await ws.close(code=4429)
            return
        sockets[token] = sockets.get(token, 0) + 1
        await ws.accept()
        previous = None
        last_touch = 0
        last_send = 0
        try:
            while True:
                now = time.monotonic()
                # Recheck on every tick so revocation also closes existing sockets.
                who = store.session(token, touch=now - last_touch > 3)
                if now - last_touch > 3:
                    last_touch = now
                data = snapshot(who)
                serial = json.dumps(data, sort_keys=True)
                if serial != previous or now - last_send > 5:
                    await asyncio.wait_for(ws.send_json(data), timeout=3)
                    previous, last_send = serial, now
                try:
                    message = await asyncio.wait_for(ws.receive(), timeout=.20)
                    if message["type"] == "websocket.disconnect":
                        break
                    # Read-only event channel; mutations have validated REST schemas.
                    if len(message.get("text") or "") > 1024 or message.get("bytes"):
                        await ws.close(code=4400)
                        break
                except asyncio.TimeoutError:
                    pass
        except AccessDenied:
            await ws.close(code=4401)
        except (WebSocketDisconnect, asyncio.TimeoutError, RuntimeError):
            pass
        finally:
            sockets[token] -= 1
            if not sockets[token]:
                del sockets[token]

    @app.get("/")
    async def index():
        return FileResponse(ROOT / "web" / "index.html")

    app.mount("/static", StaticFiles(directory=ROOT / "web"), name="static")
    return app


def main():
    parser = argparse.ArgumentParser(description="Hermes Portals companion")
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--lan", help="This laptop's private IPv4 address; enables phone access")
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Use a port between 1024 and 65535")
    if args.lan:
        try:
            address = ipaddress.ip_address(args.lan)
            if address.version != 4 or not address.is_private or address.is_loopback or address.is_unspecified:
                raise ValueError()
        except ValueError:
            parser.error("--lan must be this laptop's private IPv4 address")
    directory = args.data_dir.resolve()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = (directory / "service.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        parser.error("Portals is already running for this data directory")
    instance = uuid.uuid4().hex
    store = Store(directory)
    store.reset_access()
    app = create_app(directory, args.port, args.lan, instance=instance)
    runtime = {"port": args.port, "lan": args.lan, "instance": instance}
    path = directory / "runtime.json"
    path.write_text(json.dumps(runtime))
    path.chmod(0o600)
    # No tokens in logs; native /portals open issues a one-use local invitation.
    try:
        server = uvicorn.Server(uvicorn.Config(
            app, host="0.0.0.0" if args.lan else "127.0.0.1", port=args.port,
            access_log=False, log_level="warning", ws_max_size=1024, limit_concurrency=40,
        ))
        app.state.shutdown = lambda: setattr(server, "should_exit", True)
        server.run()
    finally:
        if path.exists() and json.loads(path.read_text()).get("instance") == instance:
            path.unlink()
        lock.close()


if __name__ == "__main__":
    main()
