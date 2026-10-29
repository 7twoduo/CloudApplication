"""Tasks API: AWS Lambda handler behind an API Gateway HTTP API (payload v2.0).

Routes:
    GET  /             Browser test page with buttons for every route.
    GET  /health       Liveness check.
    POST /tasks        Create a task from {"title": "..."}.
    GET  /tasks/{id}   Fetch a single task.

Environment:
    TASKS_TABLE        Name of the DynamoDB table that stores tasks.
"""

import json
import logging
import os
import uuid
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ["TASKS_TABLE"]
MAX_TITLE_LENGTH = 200

# Created once per execution environment and reused on warm invocations.
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


# ---------------------------------------------------------------------------
# Responses
# ---------------------------------------------------------------------------

def response(status_code, body):
    """Build an API Gateway response with a JSON body."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def error(status_code, message):
    """Build an error response shaped as {"error": message}."""
    return response(status_code, {"error": message})


def html_response(html):
    """Build an API Gateway response with an HTML body."""
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html; charset=utf-8"},
        "body": html,
    }


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

def create_task(event):
    """POST /tasks: validate the request body and store a new task."""
    try:
        body = json.loads(event.get("body") or "{}")
    except (json.JSONDecodeError, TypeError):
        return error(400, "Invalid JSON")

    if not isinstance(body, dict):
        return error(400, "JSON body must be an object")

    title = body.get("title")
    if not isinstance(title, str) or not title.strip():
        return error(400, "A title is required")

    title = title.strip()
    if len(title) > MAX_TITLE_LENGTH:
        return error(400, "Title is too long")

    task = {
        "id": str(uuid.uuid4()),
        "title": title,
        "status": "OPEN",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    table.put_item(Item=task)

    logger.info("Created task %s", task["id"])
    return response(201, task)


def get_task(event):
    """GET /tasks/{id}: return one task, or 404 if it does not exist."""
    task_id = (event.get("pathParameters") or {}).get("id")
    if not task_id:
        return error(400, "Task ID is required")

    task = table.get_item(Key={"id": task_id}).get("Item")
    if not task:
        return error(404, "Task not found")

    return response(200, task)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def lambda_handler(event, context):
    """Route each request by HTTP method and path."""
    method = event.get("requestContext", {}).get("http", {}).get("method")
    path = event.get("rawPath", "/")

    # Open the API's base URL in a browser to click through every route.
    if method == "GET" and path == "/":
        return html_response(TEST_PAGE)

    if method == "GET" and path == "/health":
        return response(200, {"status": "ok"})

    try:
        if method == "POST" and path == "/tasks":
            return create_task(event)

        if method == "GET" and path.startswith("/tasks/"):
            return get_task(event)

        return error(404, "Route not found")

    except ClientError:
        logger.exception("DynamoDB request failed")
        return error(500, "Database operation failed")


# ---------------------------------------------------------------------------
# Browser test page (served at GET /)
# ---------------------------------------------------------------------------

TEST_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tasks API tester</title>
<style>
  :root { color-scheme: light dark; --bg: #f5f6f8; --card: #fff; --ink: #1b1f24;
          --muted: #5b6470; --line: #d9dee5; --accent: #2563eb; --ok: #15803d; --bad: #b91c1c; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #0f1115; --card: #171a21; --ink: #e7eaee; --muted: #9aa4b0;
            --line: #2a2f38; --accent: #3b82f6; --ok: #16a34a; --bad: #dc2626; }
  }
  * { box-sizing: border-box; }
  body { margin: 0; font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
         background: var(--bg); color: var(--ink); }
  main { max-width: 760px; margin: 0 auto; padding: 32px 20px 48px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  h2 { font-size: 15px; margin: 0 0 10px; }
  .sub { color: var(--muted); margin: 0 0 24px; }
  section { background: var(--card); border: 1px solid var(--line); border-radius: 10px;
            padding: 16px 18px; margin-bottom: 14px; }
  .row { display: flex; gap: 8px; flex-wrap: wrap; }
  input { flex: 1 1 260px; padding: 9px 11px; border: 1px solid var(--line); border-radius: 8px;
          background: var(--bg); color: var(--ink); font: inherit; }
  button { padding: 9px 14px; border-radius: 8px; border: 1px solid var(--accent);
           background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  button.ghost { background: transparent; color: var(--accent); }
  button:disabled { opacity: .6; cursor: wait; }
  .meta { display: flex; gap: 10px; align-items: center; font-size: 13px; color: var(--muted);
          margin-bottom: 8px; }
  .badge { font-weight: 700; padding: 2px 9px; border-radius: 999px; color: #fff; }
  pre { margin: 0; padding: 12px; background: var(--bg); border: 1px solid var(--line);
        border-radius: 8px; overflow: auto; white-space: pre-wrap; word-break: break-word;
        font: 13px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
</style>
</head>
<body>
<main>
  <h1>Tasks API tester</h1>
  <p class="sub">Each button sends a real request to this API. The result shows under Response.</p>

  <section>
    <h2>1. Health check</h2>
    <div class="row"><button data-action="health">GET /health</button></div>
  </section>

  <section>
    <h2>2. Create a task</h2>
    <div class="row">
      <input id="title" placeholder="Task title, e.g. Fix login bug">
      <button data-action="create">POST /tasks</button>
    </div>
  </section>

  <section>
    <h2>3. Look up a task</h2>
    <div class="row">
      <input id="taskId" placeholder="Task ID (filled in after you create one)">
      <button data-action="get">GET /tasks/{id}</button>
    </div>
  </section>

  <section>
    <h2>4. Error cases</h2>
    <div class="row">
      <button class="ghost" data-action="blank">Blank title</button>
      <button class="ghost" data-action="badjson">Invalid JSON</button>
      <button class="ghost" data-action="long">Title too long</button>
      <button class="ghost" data-action="missing">Unknown task ID</button>
    </div>
  </section>

  <section>
    <h2>Response</h2>
    <div class="meta"><span id="badge" class="badge" hidden></span><span id="summary">No request sent yet.</span></div>
    <pre id="out">-</pre>
  </section>
</main>
<script>
const $ = (id) => document.getElementById(id);

function show(status, summary, text) {
  const badge = $("badge");
  badge.hidden = false;
  badge.textContent = status || "ERR";
  badge.style.background = status >= 200 && status < 300 ? "var(--ok)" : "var(--bad)";
  $("summary").textContent = summary;
  $("out").textContent = text || "(empty body)";
}

async function send(method, path, body) {
  const options = { method, headers: {} };
  if (body !== undefined) {
    options.headers["Content-Type"] = "application/json";
    options.body = body;
  }
  $("summary").textContent = method + " " + path + " ...";
  const started = performance.now();
  let status = 0, text = "", data = null;
  try {
    const res = await fetch(path, options);
    status = res.status;
    text = await res.text();
    data = JSON.parse(text);
    text = JSON.stringify(data, null, 2);
  } catch (err) {
    if (!status) text = "Request failed: " + err;
  }
  show(status, method + " " + path + " · " + Math.round(performance.now() - started) + " ms", text);
  return data;
}

const actions = {
  health: () => send("GET", "/health"),
  create: async () => {
    const task = await send("POST", "/tasks", JSON.stringify({ title: $("title").value }));
    if (task && task.id) $("taskId").value = task.id;
  },
  get: async () => {
    const id = $("taskId").value.trim();
    if (!id) return show(0, "Enter a task ID first (create a task to get one).", "");
    return send("GET", "/tasks/" + encodeURIComponent(id));
  },
  blank: () => send("POST", "/tasks", JSON.stringify({ title: "   " })),
  badjson: () => send("POST", "/tasks", "{not json"),
  long: () => send("POST", "/tasks", JSON.stringify({ title: "x".repeat(201) })),
  missing: () => send("GET", "/tasks/does-not-exist"),
};

document.querySelectorAll("button[data-action]").forEach((button) => {
  button.addEventListener("click", async () => {
    const all = document.querySelectorAll("button");
    all.forEach((b) => (b.disabled = true));
    try { await actions[button.dataset.action](); }
    finally { all.forEach((b) => (b.disabled = false)); }
  });
});
</script>
</body>
</html>
"""