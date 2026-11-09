# Validation evidence

This page separates automated checks from manual observations. It contains
synthetic example data only; raw local journals and device/session details are
not part of the release.

## Release preparation results — 9 November 2026

| Check | Result |
| --- | --- |
| Clean source setup, pinned companion dependencies and MediaPipe assets | Passed on macOS Apple silicon |
| Python suite in that clean environment | 22 passed |
| JavaScript suite, including Gesture Lab | 17 passed |
| Swift compile and pure recognizer tests from the clean source | 212 assertions passed; no OS events |
| Hermes 0.20.5 Plugin Doctor | Discovery, import and two tool registrations passed |
| Hermes 0.23.0 catalog validator preflight | 15 checks passed; safe; no warnings |

The Python run reports a Starlette/httpx test-client deprecation warning.
It does not fail the tests. Linux is covered by CI, not a local hardware trial.

Gesture Lab's illustrated handoff sequence is fed into the actual browser
gesture recognizer by a test and produces exactly one transfer signal. A second
test checks that all four illustrated hands remain finite and within the preview.
These tests do not send a transfer or measure a physical hand. Browser checks
cover the four modes, numbered steps, English/Bulgarian, replay and a 390-pixel
mobile viewport without horizontal overflow. These illustrated examples do not
access the camera and are not a substitute for the physical trials below.

The live practice area has additional tests for a successful camera gesture,
grabbing over the card, release boundaries, hand loss, multiple-hand cancellation,
brief tracking recovery, separate pointer/keyboard counters, video crop alignment,
and camera cleanup. A raw preview consumer cannot call the real handoff callback.
Browser checks exercised keyboard and mouse transfer, state changes and return.
The user tried the live camera and then recorded one successful gesture in a
separate local recording studio using the same recognizer and practice model.
That privacy-blurred clip is included under `docs/media`; its virtual phone is
explicitly labelled and is not evidence of a physical device transfer.

## Automated coverage

The Python suite exercises pairing expiry and replay, owner/phone access,
Host/Origin/body restrictions, transactional revisions, concurrent edits,
handoff/return, persistence and migration, revocation, reconnects, offline
receivers, tool switching, calculator validation and native-control boundaries.
The JavaScript suite covers deterministic graph/tool calculations and rejected
or accepted gesture sequences. Native self-tests exercise recognition and
pointer filtering without camera capture or OS input.

```bash
./scripts/setup.sh
uv pip install --python .venv/bin/python --require-hashes -r requirements-dev.lock
.venv/bin/python -m pytest -q
npm test
./scripts/build_macos.sh  # macOS only; runs pure self-tests
```

Catalog validation uses Hermes 0.23.0 at upstream commit
`2bd378ed1b8d6bf2192cb26e0a55ff3091e6bd19` in an isolated environment. The
preflight passed all 15 reported checks, with security result `safe`, no warnings,
and host-ready isolation. Re-run against the exact proposed release commit:

```bash
hermes plugins validate /absolute/path/to/clean-source-checkout --install-deps
```

Passing the scanner is not a security audit or maintainer approval. CI runs
the same source checks, companion suites on Linux/macOS, native compilation on
macOS and catalog validation in a separate job.

## Manual browser trials

- Diagram failure/rerouting, handoff and return preserved identity and state.
- Checklist edits persisted across both browser sessions and tool switching.
- Calculator changes from each session persisted after reload and return.
- Invalid numeric values blocked transfer instead of silently losing edits.
- Revocation invalidated the receiver; the native/browser camera modes were
  checked for mutual exclusion.

Checklist/calculator receiver trials used a second browser session and a narrow
viewport. They do not establish physical Android/iPhone coverage for every tool.
The screenshots show synthetic calculator examples and a browser receiver;
they are illustrations of the UI, not physical-device certification.

## Physical trial — 9 November 2026

- The tester confirmed that the adjusted pointer could hold a target steadily.
- The tester reported three target clicks from three index taps. Browser
  instrumentation independently showed two target clicks and one outside click;
  therefore a measured 100% target-hit rate is **not** claimed.
- The tester confirmed scrolling in both directions and an app switch followed
  by a return. The intended scroll/focus counters did not independently verify
  both results; these remain tester-reported observations.
- Physical Escape was observed stopping capture/input.
- A physical iPhone was paired by QR. Camera-gesture transfer preserved the
  diagram with Server A disabled and the route through Server B.
- The final laptop state showed all nodes restored and the diagram returned
  from the phone. An earlier restoration attempt was inconclusive; no root
  cause or code fix was established during that trial.

These are single-user development observations, not gesture-accuracy statistics.
Camera placement, lighting, occlusion, different users, Android browsers and
Linux camera/hardware behavior still need broader testing. Native permission
renewal after an ad-hoc rebuild remains a known setup limitation.
