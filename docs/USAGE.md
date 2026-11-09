# Using Hermes Portals

Start with the [README quickstart](../README.md#start-here). This reference covers
commands, saved tools and the local development workflow.

## Commands and sessions

```text
/portals open       # new one-use laptop invitation
/portals status     # service, active tool, library and phone status
/portals revoke     # revoke phone and return active tool to laptop
/portals stop       # gracefully stop companion; keep saved tools
/portals mac open   # open Mac controller; choose Preview or Control there
/portals mac status # native capture/control and permission status
/portals mac stop   # stop native camera/input; leave the menu bar app open
```

Each `/portals open` invalidates older unredeemed owner invitations. Redeeming
a new owner invitation replaces the prior owner session. Restarting the service
requires pairing again, while preserving all saved tools. An interrupted phone
can reconnect with its existing session while that service remains running.
The native Mac controller is independent: `/portals stop` does not stop it.
Use `/portals mac stop`, Escape, its Stop button or Quit for that mode.

Standalone developer use (same backend and state model):

```bash
.venv/bin/python scripts/portals.py --data-dir .runtime/demo start <laptop-IP>
.venv/bin/python scripts/portals.py --data-dir .runtime/demo open
.venv/bin/python scripts/portals.py --data-dir .runtime/demo stop
```


## Ask Hermes

In a fresh Hermes conversation after enabling/updating the plugin, ask:

- “Create a Portals checklist for my project launch: review scope, test the
  prototype, collect feedback, and prepare release notes.”
- “Create a Portals calculator for team size × working days × daily cost.”
- “List my saved Portals tools, open the launch checklist, and send it to my phone.”

`portals_app` supports status/list, create, template, open, set_item, set_value
and handoff. It reads the current workspace revision before every mutation.
The companion must be running for browser delivery, and the phone must be
paired and online for handoff. Tool creation itself can happen while stopped.
See [the portable tool contract](docs/PORTABLE_TOOLS.md) for payload examples,
supported calculations and extension points.

Ask Hermes: “Use Portals to disable Server A in the demo diagram and send it to
my paired phone.” The `portals_diagram` tool reads `status`, then applies an
explicit mutation using the latest revision. Concurrent edits receive a conflict
instead of silently overwriting another device's changes.

For `show`, the tool accepts a bounded data-only graph: a title, 2–12 nodes
`{id,label,x,y}`, up to 30 directed edges `[from,to]`, and `source`/`sink` IDs.
Coordinates range from 0.08 to 0.92. The renderer changes layout on narrow screens.
It does not execute HTML or JavaScript supplied by a model. Node failures and
the resulting route are a deterministic graph demonstration, not a capacity,
reliability or load simulation of a real deployment.


## Saving and switching tools

Try **+ Checklist** or **+ Calculator**, then reopen a tool from **Your saved
tools**. The library keeps up to 30 tools and their saved state. Only one is
active at a time. Calculator sliders save on release; typed inputs save with
Enter or **Save changes**, and before a handoff or tool switch.

## Practice before a real handoff

From the laptop page, open **Try with your hand**. Gesture Lab offers a live
camera preview, a sample card and a virtual phone. Mouse, touch and keyboard
practice work with the camera off; their successes are counted separately.
Camera practice requires the signed-in localhost owner session so it can check
that native capture is stopped. It never changes a real artifact or emits OS
input. Escape, hiding the page or closing it stops the browser camera.

The collapsible illustrated guide covers handoff, index tapping, scrolling and
app switching in English and Bulgarian. Play, pause, scrub or select a step.

## Install a development checkout

```bash
hermes plugins install file:///absolute/path/to/hermes-portals
hermes plugins validate /absolute/path/to/hermes-portals --install-deps
hermes plugins enable hermes-portals --no-allow-tool-override
```

Use Hermes 0.23.0+ for the catalog validator. Run it against a clean source
checkout before setup downloads ignored runtime assets. See [Contributing](../CONTRIBUTING.md)
for development tests and [Publishing](PUBLISHING.md) for exact-commit validation.
