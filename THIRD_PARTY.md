# Third-party components

The source checkout excludes downloaded runtime binaries and model weights.
`scripts/setup.sh` explicitly prepares them under the git-ignored `web/vendor/`.

- `@mediapipe/tasks-vision` **0.10.32**, Google MediaPipe, npm metadata license:
  Apache-2.0. Exact tarball integrity is recorded in `package-lock.json`.
  [Source](https://github.com/google-ai-edge/mediapipe).
- MediaPipe Hand Landmarker model, float16, version **1**:
  `https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task`.
  SHA-256 is recorded in `scripts/model.sha256`. Consult Google's model
  documentation and licensing terms before redistribution.
- Python dependencies and their transitive versions/hashes are recorded in
  `requirements.lock`; their distributions carry their respective licenses.
- The optional macOS helper links Apple's system AppKit, AVFoundation,
  ApplicationServices and Vision frameworks. No additional hand-tracking model
  is downloaded for that mode. No code from Pawvis or another gesture-control
  project is included.

Original Hermes Portals source is MIT licensed; see LICENSE. Third-party
components retain their own licenses. Dependencies are fetched during explicit
setup, not redistributed as committed executable payloads.
