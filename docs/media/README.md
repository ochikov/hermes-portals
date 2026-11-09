# Gesture Lab video

[Watch the MP4](hermes-portals-demo.mp4)

This recording shows a person using the real local MediaPipe hand tracker and
the production browser gesture recognizer to pick up a sample card and release
it over a virtual phone. The sample card keeps Server A offline.

- Recorded on 9 November 2026, with the participant's consent for this GitHub demo.
- The entire camera image was strongly blurred in the capture canvas **before**
  MediaRecorder received frames. Clear face imagery was never stored in the take.
- Joint landmarks, the sample card and feedback were drawn above that blur.
- No microphone stream or audio track was captured.
- The MP4 contains opening/closing titles and one continuous, real-time excerpt
  of the successful attempt. The gestures were not generated or sped up.
- The GIF is a shorter loop from the same take; the JPEG is a frame from it.
- The local studio and original take are excluded from the source release.

This is a page-local exercise with a **virtual phone**. It does not show physical
QR pairing, a transfer to a real phone, native app switching, clicks or scrolling.
Those features need their own live demonstration. This clip is not the complete
hackathon submission video described in [PUBLISHING.md](../PUBLISHING.md).

The product does not record camera footage. Recording was explicitly started in
a separate local tool for this demonstration. No recording service or dependency
is added to the plugin.
