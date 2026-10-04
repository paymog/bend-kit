"""Matched business work on plain ASGI and FastAPI; both use one Uvicorn worker."""
import json
import re
import sys
import uvicorn
from fastapi import FastAPI, Request
from starlette.responses import Response

MODE, PROFILE, PORT = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
LIMIT = 8 * 1024 * 1024
TEXT = "text/plain; charset=utf-8"
registrations = {f"/route/{i}": ("route", i) for i in range(PROFILE)} if PROFILE else {
    path: (path[1:], None) for path in ("/text", "/json", "/decode", "/echo", "/hooks/0", "/hooks/1", "/hooks/5")}


def select(path):
    if path in registrations:
        return registrations[path]
    if not PROFILE and re.fullmatch(r"/users/[^/]+", path):
        return "user", path[7:]
    return "missing", None


def reply(status, body, headers=None):
    return status, body.encode() if isinstance(body, str) else body, headers or {}


def text(status, body):
    return reply(status, body, {"content-type": TEXT})


def encoded(value, headers=None):
    return reply(200, json.dumps(value, separators=(",", ":"), ensure_ascii=False), {"content-type": "application/json", **(headers or {})})


def business(job, method, headers, body):
    op, parameter = job
    get = method in ("GET", "HEAD")
    if op == "missing":
        return text(404, "not found")
    if op in ("decode", "echo"):
        if method != "POST":
            return reply(405, "", {"allow": "POST"})
        if op == "echo":
            return reply(200, body, {"content-type": "application/octet-stream"})
        if headers.get("content-type") != "application/json":
            return text(415, "unsupported media type")
        try:
            value = json.loads(body.decode("utf-8"))
            if not isinstance(value, dict) or set(value) != {"name"} or not isinstance(value["name"], str) or not value["name"]:
                return text(400, "invalid name")
            return encoded({"name": value["name"]})
        except (ValueError, UnicodeError):
            return text(400, "invalid name")
    if op == "user":
        if not re.fullmatch(r"[0-9]+", parameter) or int(parameter) > 4294967295:
            return text(400, "invalid id")
        if not get:
            return reply(405, "", {"allow": "GET, HEAD"})
        return encoded({"id": int(parameter)})
    if not get:
        return reply(405, "", {"allow": "GET, HEAD"})
    if op == "text":
        return text(200, "OK\n")
    if op == "json":
        return reply(200, '{"ok":true}', {"content-type": "application/json"})
    if op == "route":
        return encoded({"id": parameter})
    count = int(op[6:])
    for _ in range(count):
        if headers.get("authorization") != "Bearer alice":
            return reply(401, "", {"www-authenticate": "Bearer"})
    return reply(200, '{"ok":true}', {"content-type": "application/json", "x-hook-count": str(count)})


async def raw(scope, receive, send):
    if scope["type"] != "http":
        raise RuntimeError("HTTP-only benchmark")
    chunks, length = [], 0
    while True:
        message = await receive()
        if message["type"] == "http.disconnect":
            return
        length += len(message.get("body", b""))
        if length > LIMIT:
            await send({"type": "http.response.start", "status": 413, "headers": [(b"content-length", b"0")]})
            await send({"type": "http.response.body", "body": b""})
            return
        chunks.append(message.get("body", b""))
        if not message.get("more_body", False):
            break
    headers = {k.decode("latin1"): v.decode("latin1") for k, v in scope["headers"]}
    status, body, fields = business(select(scope["path"]), scope["method"], headers, b"".join(chunks))
    fields["content-length"] = str(len(body))
    await send({"type": "http.response.start", "status": status, "headers": [(k.encode(), v.encode()) for k, v in fields.items()]})
    await send({"type": "http.response.body", "body": b"" if scope["method"] == "HEAD" else body})


app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None, redirect_slashes=False)


def endpoint(job):
    async def handle(request: Request):
        chunks, length = [], 0
        async for chunk in request.stream():
            length += len(chunk)
            if length > LIMIT:
                return Response(b"", status_code=413)
            chunks.append(chunk)
        body = b"".join(chunks)
        selected = ("user", request.path_params["id"]) if job[0] == "user" else job
        status, payload, fields = business(selected, request.method, request.headers, body)
        fields["content-length"] = str(len(payload))
        return Response(b"" if request.method == "HEAD" else payload, status_code=status, headers=fields)
    return handle


for path, job in registrations.items():
    app.add_api_route(path, endpoint(job), methods=["GET", "HEAD", "POST"])
if not PROFILE:
    app.add_api_route("/users/{id}", endpoint(("user", None)), methods=["GET", "HEAD", "POST"])
app.add_api_route("/{rest:path}", endpoint(("missing", None)), methods=["GET", "HEAD", "POST"])
uvicorn.run(raw if MODE == "raw" else app, host="127.0.0.1", port=PORT, workers=1,
            loop="uvloop", http="httptools", lifespan="off", access_log=False, log_level="warning",
            server_header=False, date_header=False)
