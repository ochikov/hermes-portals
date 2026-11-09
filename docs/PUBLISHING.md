# Publication and catalog submission

Target repository: https://github.com/ochikov/hermes-portals

The authority is the [catalog submission guide](https://hermes-agent.nousresearch.com/docs/developer-guide/plugins/catalog-submission)
and [catalog schema](https://github.com/NousResearch/hermes-agent/blob/main/plugin-catalog/README.md).
Recheck both before submitting: admission rules can change.

## Release gate

1. Review the exact tracked tree and run `python3 scripts/check_release.py`.
   Keep local test journals, machine paths, live QR codes, private sessions,
   camera images and generated binaries out of the commit.
2. Run the companion, JavaScript and native checks described in VALIDATION.md.
   Test setup in a clean checkout; existing local assets are not install evidence.
3. Commit the intended source and use a fresh clone of that **full 40-character
   SHA** for `hermes plugins validate PATH --install-deps`. Run this before
   setup downloads ignored dependencies/assets. Review every warning.
4. Ensure the repository is publicly cloneable. A private staging repository
   cannot be submitted to the catalog. Choose MIT for the original source and
   retain the third-party disclosures.
5. Add only `plugin-catalog/hermes-portals.yaml` in a catalog PR against
   NousResearch/hermes-agent. Use `tier: community`, `category: tools`,
   `platforms: [macos, linux]`, quoted version `"0.3.0"`, and the same
   `requires_hermes: ">=0.20.5"` as the manifest. Mac OS input is macOS-only;
   Linux is the companion/browser capability.
6. Declare exactly `portals_app` and `portals_diagram`, no hooks, middleware
   or required credentials. Pin screenshot URLs to the same commit. Include
   setup, permissions, network/storage/subprocess disclosures and test evidence
   in the PR body. The source repository also registers the `/portals` command.
7. Let maintainers start the admission checks and review. Passing local
   validation is not catalog acceptance. Future updates require new SHA-bump
   PRs; never add an in-app self-updater.

No native binary, WASM or model is distributed in this source release. Setup
fetches the official pinned MediaPipe npm package and Google model, with
integrity verification, and optionally compiles Swift locally. If prebuilt
native releases are introduced later, use this repository's public GitHub
Actions and GitHub build attestations tied to the reviewed source commit;
also resolve macOS signing/notarization before describing installation as
frictionless.

## Hackathon requirements

The [Nous Research announcement](https://x.com/NousResearch/status/2118094256438936062),
checked on 9 November 2026, asks for an open catalog PR, a working demo video
**under 90 seconds** posted on X with **@NousResearch**, then both URLs in the
[submission form](https://form.typeform.com/to/FwJLvOln).
The announced deadline is **11 November 2026, 17:00 EST** — **12 November
2026, 00:00 Europe/Sofia**. Do not wait for the PR to be merged to submit the
form; an open PR is sufficient according to the announcement.

The prototype's recorded manual test results are not a demo video. Record the
real build and actual hand gestures. Do not present mouse/automation input as
gesture detection, a browser viewport as a physical phone, or a pre-rendered
animation as a live transfer.

## Suggested 80-second recording

| Time | Actual action | Point to explain |
| --- | --- | --- |
| 0–10 s | Ask Hermes for a small interactive diagram; show its tool call and result | Hermes creates an interactive object |
| 10–20 s | Open Portals and pair a physical phone by QR | No phone app install |
| 20–38 s | Disable Server A; use the browser camera gesture to transfer | Same object, same failed node and route on the phone |
| 38–49 s | Restore on the phone, return to laptop | Interaction survives both directions |
| 49–58 s | Open a saved checklist or calculator | More than one hard-coded diagram |
| 58–73 s | Stop browser camera; start native control and show one click, scroll, app switch | Optional local Mac input |
| 73–80 s | Press Escape; show camera/input off and repository title | Explicit stop; open source |

Keep notifications and unrelated windows out of frame. Use synthetic content.
Do not record an active pairing URL, address bar token or private account
details. The QR shot can show scanning without a readable code in the final
crop. State "trusted-LAN prototype" and "optional Mac permissions" in captions.
If the real flow needs more time, remove a feature segment rather than speed
up or conceal failed gestures.

Suggested X text, to publish only with the completed recording:

> Hermes Portals: create interactive tools in Hermes, move them from laptop to
> phone with a hand gesture, and keep their state. Optional local Mac control
> adds pointing, clicking, scrolling and app switching. Open-source trusted-LAN
> prototype for the @NousResearch plugin hackathon.

Attach the actual video, source link and catalog PR link. Complete the form
with the owner's own contact details and these real URLs; do not invent links,
claim acceptance, or submit an unfinished video.
