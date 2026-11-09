"""Data-only portable tools. No model-supplied HTML, scripts or expressions."""
import math
import re

KINDS = ("diagram", "checklist", "calculator")
MAX_ARTIFACTS = 30


def label(value, name="Label", limit=80):
    if not isinstance(value, str) or not value.strip() or len(value) > limit:
        raise ValueError(f"{name} must be 1–{limit} characters")
    return value.strip()


def identifier(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,32}", value):
        raise ValueError("IDs must use 1–32 letters, digits, hyphens or underscores")
    return value


def number(value):
    if type(value) not in (int, float) or not math.isfinite(value) or abs(value) > 1_000_000:
        raise ValueError("Use finite numbers between -1,000,000 and 1,000,000")
    return value


def unique(entries):
    if len({entry["id"] for entry in entries}) != len(entries):
        raise ValueError("IDs must be unique")


def bounded_list(value, name, maximum):
    if not isinstance(value, list) or not 1 <= len(value) <= maximum:
        raise ValueError(f"Use 1–{maximum} {name}")
    if any(not isinstance(item, dict) for item in value):
        raise ValueError(f"Each {name} entry must be an object")
    return value


def validate_artifact(value):
    if not isinstance(value, dict):
        raise ValueError("Artifact must be an object")
    kind = value.get("kind")
    if kind not in KINDS:
        raise ValueError("Choose diagram, checklist or calculator")
    if type(value.get("schema_version", 1)) is not int or value.get("schema_version", 1) != 1:
        raise ValueError("Unsupported artifact schema version")
    common = {"kind": kind, "schema_version": 1, "title": label(value.get("title"), "Title")}
    if kind == "diagram":
        from .store import validate_graph
        graph = validate_graph(value)
        return {**common, **graph, "disabled": [], "selected": graph["source"]}
    if kind == "checklist":
        items = []
        for item in bounded_list(value.get("items"), "checklist items", 40):
            done = item.get("done", False)
            if type(done) is not bool:
                raise ValueError("done must be true or false")
            items.append({"id": identifier(item.get("id")), "label": label(item.get("label"), limit=160), "done": done})
        unique(items)
        return {**common, "items": items}
    fields = []
    for field in bounded_list(value.get("fields"), "calculator fields", 8):
        low, high, step, current = (number(field.get(key)) for key in ("min", "max", "step", "value"))
        if not low < high or step <= 0 or step > high - low or not low <= current <= high:
            raise ValueError("Fields need min < max, a positive step within the range, and a value inside the range")
        unit = field.get("unit", "")
        if not isinstance(unit, str) or len(unit) > 16:
            raise ValueError("Unit must be at most 16 characters")
        fields.append({"id": identifier(field.get("id")), "label": label(field.get("label")),
                       "min": low, "max": high, "step": step, "value": current, "unit": unit})
    unique(fields)
    ids = {field["id"] for field in fields}
    outputs = []
    for output in bounded_list(value.get("outputs"), "calculator outputs", 4):
        refs = output.get("fields")
        if not isinstance(refs, list) or not 1 <= len(refs) <= 8 or any(not isinstance(ref, str) or ref not in ids for ref in refs):
            raise ValueError("Outputs must refer to 1–8 existing field IDs")
        if output.get("operation") not in ("sum", "product"):
            raise ValueError("Calculator operations are sum or product")
        unit = output.get("unit", "")
        if not isinstance(unit, str) or len(unit) > 16:
            raise ValueError("Unit must be at most 16 characters")
        outputs.append({"id": identifier(output.get("id")), "label": label(output.get("label")),
                        "operation": output["operation"], "fields": refs, "unit": unit})
    unique(outputs)
    return {**common, "fields": fields, "outputs": outputs}


def update_artifact(obj, action):
    kind = obj.get("kind", "diagram")
    action_type = action.get("type")
    if action_type == "set_item" and kind == "checklist":
        item = next((item for item in obj["items"] if item["id"] == action.get("item")), None)
        if item is None or type(action.get("done")) is not bool:
            raise ValueError("Choose an existing item and a boolean done value")
        item["done"] = action["done"]
    elif action_type in ("set_value", "set_values") and kind == "calculator":
        values = action.get("values") if action_type == "set_values" else {action.get("field"): action.get("value")}
        if not isinstance(values, dict) or not 1 <= len(values) <= 8:
            raise ValueError("Supply 1–8 calculator values")
        for ident, raw in values.items():
            field = next((field for field in obj["fields"] if field["id"] == ident), None)
            value = number(raw)
            if field is None or not field["min"] <= value <= field["max"]:
                raise ValueError("Choose an existing field and a value inside its range")
        for field in obj["fields"]:
            if field["id"] in values:
                field["value"] = values[field["id"]]
    else:
        raise ValueError("This action does not apply to the active tool")


def template(kind):
    if kind == "diagram":
        from .store import demo
        return {**demo(), "kind": "diagram"}
    if kind == "checklist":
        return {"kind": "checklist", "title": "Project launch", "items": [
            {"id": "scope", "label": "Agree on the scope"},
            {"id": "prototype", "label": "Test the prototype on both devices"},
            {"id": "feedback", "label": "Collect feedback"},
            {"id": "launch", "label": "Prepare the launch"},
        ]}
    if kind == "calculator":
        return {"kind": "calculator", "title": "Project estimate", "fields": [
            {"id": "people", "label": "Team size", "min": 1, "max": 12, "step": 1, "value": 3, "unit": "people"},
            {"id": "days", "label": "Working days", "min": 1, "max": 90, "step": 1, "value": 20, "unit": "days"},
            {"id": "rate", "label": "Cost per person / day", "min": 100, "max": 2000, "step": 25, "value": 500, "unit": "EUR"},
        ], "outputs": [
            {"id": "effort", "label": "Total effort", "operation": "product", "fields": ["people", "days"], "unit": "person-days"},
            {"id": "estimate", "label": "Estimated cost", "operation": "product", "fields": ["people", "days", "rate"], "unit": "EUR"},
        ]}
    raise ValueError("Unknown template")
