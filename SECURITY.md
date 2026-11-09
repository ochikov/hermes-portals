# Security policy

Hermes Portals 0.3 is a trusted-LAN prototype. The current 0.3 release is the
supported version. Do not expose its HTTP service to the internet or put
sensitive production content in a demo room.

Report a vulnerability privately through the repository's **Security → Report
a vulnerability** page when available. Do not put working tokens, private
content, camera images or exploitation details in a public issue. If private
reporting is unavailable, open an issue asking the maintainer for a private
channel without disclosing the vulnerability itself.

Include the plugin commit, operating system, affected component and minimal
reproduction with synthetic data. No paid bounty or response SLA is offered.

## Boundaries

- Native Hermes tools accept data only. They cannot execute supplied code.
- The companion validates Host, Origin, session role, payload size and revision.
  Invitations are single-use and expire in two minutes; sessions expire in
  eight hours. A restart clears access while keeping saved artifacts.
- Phone access applies to the shared artifact, not the Mac's filesystem or
  native input. Native open/status/stop requires the authenticated loopback
  owner; no HTTP endpoint accepts mouse, keyboard or app-switch actions.
- Mac Camera and Accessibility grants belong to the optional local helper.
  Control requires a native user action and palm activation. Escape stops it.
- Browser and native camera processing stay local. No recording or telemetry.
- LAN HTTP is **not encrypted**. Pairing does not protect against an attacker
  able to observe or modify network traffic. Use a trusted private network.
- Source distributions contain no compiled native/WASM payloads. Explicit
  setup fetches the pinned npm package and checksum-verified official Google
  model; optional native control compiles the Swift sources locally.

See [README disclosures](README.md#access-and-network-disclosure) for storage,
subprocesses, setup downloads and lifecycle details. Updates use a new reviewed
catalog commit; the plugin never updates itself.
