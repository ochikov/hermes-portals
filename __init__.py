"""Hermes integration through its documented tool and slash-command APIs."""
import json

def data_dir():
    # Resolve on every invocation: a Hermes process may serve multiple profiles.
    from plugins.plugin_storage import plugin_data_dir
    return plugin_data_dir("hermes-portals")


SCHEMA = {
    "name": "portals_diagram",
    "description": "Read or change the interactive diagram in the user's Portals room. "
        "Only diagram simulation state changes; this does not operate real infrastructure. "
        "Use status to obtain revision before changing anything. The user starts/pairs devices via /portals.",
    "parameters": {"type": "object", "properties": {
        "action": {"type": "string", "enum": ["status", "show", "set_node", "handoff", "restore"]},
        "revision": {"type": "integer", "description": "Required for mutations; latest revision from status."},
        "node": {"type": "string"}, "enabled": {"type": "boolean"},
        "target": {"type": "string", "enum": ["laptop", "phone"]},
        "diagram": {"type": "object", "description": "For show: title, 2–12 nodes {id,label,x,y}; "
            "normalized positions 0.08–0.92; edges [[from,to]], source and sink node IDs.",
            "properties": {
                "title": {"type": "string"},
                "nodes": {"type": "array", "minItems": 2, "maxItems": 12, "items": {
                    "type": "object", "properties": {"id": {"type": "string"}, "label": {"type": "string"},
                        "x": {"type": "number"}, "y": {"type": "number"}}, "required": ["id", "label", "x", "y"]}},
                "edges": {"type": "array", "items": {"type": "array", "items": {"type": "string"}}},
                "source": {"type": "string"}, "sink": {"type": "string"}},
            "required": ["title", "nodes", "edges", "source", "sink"]},
    }, "required": ["action"], "additionalProperties": False},
}


def diagram_tool(args: dict, **kwargs) -> str:
    from .portals.store import Conflict, Store
    store = Store(data_dir())
    action = args.get("action", "status")
    try:
        if action == "status":
            return json.dumps({**store.workspace(), "phone": store.phone()})
        revision = args.get("revision")
        if type(revision) is not int:
            raise ValueError("Read status and supply its revision before changing the diagram")
        value = store.mutate({**args, "type": action}, revision)
        return json.dumps({"artifact": value})
    except (ValueError, Conflict, TypeError) as error:
        return json.dumps({"error": str(error), "artifact": store.snapshot()})


APP_SCHEMA = {
    "name": "portals_app",
    "description": "Create, list, open, edit and transfer portable interactive tools in Hermes Portals. "
        "Supports diagrams, checklists and calculators, each saved independently. Read status/list for the "
        "current workspace revision and saved IDs before mutations. Only the active tool is edited or handed off. "
        "The user starts the local companion and pairs a phone with /portals. Data only; cannot run arbitrary apps or code.",
    "parameters": {"type": "object", "properties": {
        "action": {"type": "string", "enum": ["status", "list", "create", "template", "open", "set_item", "set_value", "handoff"]},
        "revision": {"type": "integer", "description": "Latest workspace revision; required for every mutation."},
        "artifact_id": {"type": "string", "description": "Saved tool ID for open. Opening returns that tool to the laptop."},
        "template": {"type": "string", "enum": ["diagram", "checklist", "calculator"], "description": "For template: create a new example tool."},
        "item": {"type": "string", "description": "Checklist item ID for set_item."},
        "done": {"type": "boolean"},
        "field": {"type": "string", "description": "Calculator field ID for set_value."},
        "value": {"type": "number"},
        "target": {"type": "string", "enum": ["laptop", "phone"]},
        "artifact": {"type": "object", "description": "For create. Supply kind and title plus the matching fields. "
            "Calculator outputs use only sum or product of listed input field IDs; no executable expressions. "
            "At most 30 saved tools per workspace.", "properties": {
            "kind": {"type": "string", "enum": ["diagram", "checklist", "calculator"]},
            "title": {"type": "string", "maxLength": 80},
            "items": {"type": "array", "minItems": 1, "maxItems": 40, "items": {"type": "object", "properties": {
                "id": {"type": "string"}, "label": {"type": "string"}, "done": {"type": "boolean"}}, "required": ["id", "label"]}},
            "fields": {"type": "array", "minItems": 1, "maxItems": 8, "items": {"type": "object", "properties": {
                "id": {"type": "string"}, "label": {"type": "string"}, "min": {"type": "number"},
                "max": {"type": "number"}, "step": {"type": "number"}, "value": {"type": "number"},
                "unit": {"type": "string"}}, "required": ["id", "label", "min", "max", "step", "value"]}},
            "outputs": {"type": "array", "minItems": 1, "maxItems": 4, "items": {"type": "object", "properties": {
                "id": {"type": "string"}, "label": {"type": "string"}, "operation": {"type": "string", "enum": ["sum", "product"]},
                "fields": {"type": "array", "items": {"type": "string"}}, "unit": {"type": "string"}},
                "required": ["id", "label", "operation", "fields"]}},
            **SCHEMA["parameters"]["properties"]["diagram"]["properties"],
        }, "required": ["kind", "title"]},
    }, "required": ["action"], "additionalProperties": False},
}


def app_tool(args: dict, **kwargs) -> str:
    from .portals.store import Conflict, Store
    store = Store(data_dir())
    try:
        action = args.get("action", "status")
        if action not in ("status", "list"):
            revision = args.get("revision")
            if type(revision) is not int:
                raise ValueError("Read status and supply its revision before changing the workspace")
            store.mutate({**args, "type": action}, revision)
        return json.dumps({**store.workspace(), "phone": store.phone()})
    except (ValueError, Conflict, TypeError) as error:
        return json.dumps({"error": str(error), **store.workspace()})


def register(ctx):
    from .portals.service import command
    ctx.register_tool(name="portals_diagram", toolset="portals", schema=SCHEMA, handler=diagram_tool)
    ctx.register_tool(name="portals_app", toolset="portals", schema=APP_SCHEMA, handler=app_tool)
    ctx.register_command("portals", lambda raw: command(data_dir(), raw),
                         description="Open Portals, pair a phone, and transfer interactive tools with hand gestures",
                         args_hint="start [LAN-IP] | open | status | revoke | stop | mac open/status/stop")
