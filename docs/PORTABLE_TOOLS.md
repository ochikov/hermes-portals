# Portable tools in 0.2

Portals is a Hermes plugin plus an explicitly started local browser companion.
Hermes creates a tool from bounded data; the browser renders its interactive
controls. A paired phone receives the same tool ID and saved state. The same
button or local webcam gesture hands off every supported kind.

## User journey

1. In a fresh Hermes conversation, run `/portals start <laptop LAN IPv4>` and open
   the one-use localhost link. Scan the QR from a phone on the same trusted Wi-Fi.
2. Ask: “Create a Portals checklist for these launch tasks: review scope, test
   the prototype, collect feedback, prepare release notes.”
3. Hermes reads `portals_app` status, then calls `create` with that revision.
   The new checklist appears on the laptop and in **Your saved tools**.
4. Check a task. Send it to the phone with the button or the existing camera
   gesture. Check another task there, then return it. Both edits stay saved.
5. Create a calculator or open a saved diagram. Reopen the checklist later;
   changing tools does not erase its ticks.

The page also includes three sample-creation buttons for trying this without
an LLM call. Samples are explicitly created on demand, not silently seeded.

## Current contract

Every artifact has `id`, `kind`, `schema_version: 1`, `title`, `revision` and
`display` (`laptop` or `phone`). Version 1 intentionally uses a flat payload to
retain compatibility with the original diagram tool. The workspace has one
active artifact and a library of at most 30 saved artifacts. All saved tools
are visible to the paired participant through the library metadata. The phone
cannot create tools or switch the active tool, but can edit and recall the
active tool. This is a cooperative room, not exclusive edit ownership.

`revision` is a monotonically increasing **workspace** revision, including
when opening a different saved tool. Every native/browser mutation requires
the current revision. A stale edit is rejected, including when a second tool
has an item or field with the same ID. Updates are not automatically retried.

| Kind | Definition and state | Mutations |
| --- | --- | --- |
| `diagram` | 2–12 nodes, bounded positions, directed edges, source/sink, selected node, disabled nodes | `select`, `set_node`, `restore` |
| `checklist` | 1–40 `{id, label, done}` items | `set_item` with item ID and boolean `done` |
| `calculator` | 1–8 bounded numeric fields, 1–4 outputs | `set_value` with field ID and numeric `value` |

Calculator outputs declare `sum` or `product` and a list of input field IDs.
The UI shows that formula alongside each result. Numbers must be finite and
within ±1,000,000; each value must also fit the field's min/max. `step` controls
slider/keyboard increments; the server allows any finite value within the
range, so precise manual input remains possible. Outputs are derived from
saved inputs rather than persisted independently. Slider previews are local;
release commits. Typed edits commit with Enter or **Save changes**. Handoff and
tool switching first commit all pending numeric edits in one `set_values`
transaction; invalid or conflicting saves cancel the transition. The camera
gesture uses this same path. A typed preview is explicitly labelled until saved.

Example `portals_app` create payload (replace the revision with fresh status):

```json
{
  "action": "create",
  "revision": 12,
  "artifact": {
    "kind": "calculator",
    "title": "Workshop capacity",
    "fields": [
      {"id": "tables", "label": "Tables", "min": 1, "max": 30, "step": 1, "value": 8},
      {"id": "seats", "label": "Seats per table", "min": 1, "max": 12, "step": 1, "value": 6}
    ],
    "outputs": [
      {"id": "capacity", "label": "Total capacity", "operation": "product", "fields": ["tables", "seats"], "unit": "people"}
    ]
  }
}
```

## Storage and extension points

- SQLite's original `artifact` row remains the active snapshot. A new `library`
  table stores each tool. Mutations write both in one transaction. Workspace
  snapshots read active state and library metadata in one read transaction.
- Existing 0.1 diagrams acquire `kind` and `schema_version` without changing
  their IDs, selected nodes, simulated failures or revisions.
- `portals/artifacts.py` owns validation, templates and kind-specific mutations.
  `portals/store.py` owns revision checks, access and persistence.
- `web/tools.mjs` owns the additional renderers and deterministic calculator
  evaluator. `web/graph.mjs` remains the diagram renderer.
- To add a kind, add its bounded validator/mutations, renderer and native schema,
  then test save/open, handoff/return, stale edits and reconnect. No changes to
  pairing or gesture recognition should be necessary.

## Boundaries

These are supported interactive mini-tools, not arbitrary third-party apps.
There is no app process migration, screen streaming, arbitrary HTML/JavaScript
execution, file transfer or general expression engine in the portable-tool contract.
No Pawvis dependency or integration has been added. The existing browser-local
MediaPipe gesture pipeline remains in use.

One laptop and one phone share one active tool; the rest remain saved. Opening
a tool always brings it to the laptop. There is no delete/archive UI yet.
Restarting the companion preserves all content but requires fresh pairing.
If Wi-Fi changes, stop and start with the laptop's new LAN address. Transport
is still HTTP on a trusted LAN; this version is not a public hosting setup.

Version 0.3 adds a separate optional [native Mac controller](MAC_CONTROL.md) for
pointer movement, clicks, scrolling and switching running apps. It does not
extend the phone's permissions or migrate arbitrary applications. Portable
tool handoff retains its browser-local MediaPipe recognizer.
