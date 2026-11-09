# Contributing

Use synthetic examples and keep changes scoped. Open an issue describing a
problem before adding a new portable tool kind or native gesture.

```bash
./scripts/setup.sh
uv pip install --python .venv/bin/python --require-hashes -r requirements-dev.lock
.venv/bin/python -m pytest -q
npm test
```

On macOS, `./scripts/build_macos.sh` also compiles and runs the pure gesture
recognizer self-test. It does not start capture or send OS input. Rebuilding a
previously authorized helper may require renewing its macOS permissions.

Run the current Hermes catalog validator against a clean source checkout:
`hermes plugins validate /absolute/path/to/hermes-portals --install-deps`.
Keep the Python adapter on public Hermes APIs and its dependencies in the
separate companion environment. Document every new permission, subprocess,
network destination and persistent field. Never commit runtime databases,
pairing links, camera footage, machine paths or compiled payloads.

Physical gesture tests are manual and must be reported separately from
synthetic recognizer assertions. Use the inert `/static/gesture-test.html` page
and physical Escape to stop. Do not claim a gesture succeeds merely because
a counter changed after mouse or automation input.

Contributions to the original project source are under the MIT license.
