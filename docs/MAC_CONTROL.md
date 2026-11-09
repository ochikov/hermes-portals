# Mac gesture control — prototype 0.3

Hermes Portals now has two camera modes. The browser's **Portals camera** sends
supported interactive tools to a paired phone. The optional **Mac controller**
uses Apple's Vision hand tracker to move the pointer, click, scroll and switch
running apps. It keeps tracking when another app is in front, so the browser
does not need to remain visible. These modes have separate recognizers.

## Start on a Mac

macOS 13 or later and Apple's Swift compiler are required. Build once from the
checkout with `./scripts/build_macos.sh`; `./scripts/setup.sh --with-mac` also builds it
when Swift is available. The build produces
`native/macos/build/Hermes Portals Control.app` for the current CPU architecture.
It is locally ad-hoc signed, not notarized. The public repository distributes source only.
Rebuilding can require renewing the app's macOS permissions.

1. Run `/portals mac open` in Hermes, or press **Open Mac controller** in the
   localhost laptop page. Opening the controller leaves camera and control off.
2. Press **Start preview** and allow Camera access. Check that the mirrored
   **Live hand** panel appears on the right. It shows the camera, up to 21 hand
   joints and their connecting lines, a bright index-tip dot and the detected
   pose. An orange dot indicates the selected click gesture. Preview never sends
   mouse events or changes the active app.
3. Press **Request Accessibility…**. In System Settings → Privacy & Security →
   Accessibility, enable **Hermes Portals Control** yourself. If it is not listed,
   use **Show app in Finder** to locate the built app and add it with the settings
   panel's plus button. This permission lets the helper send real mouse input.
   Grant it to this helper, not to the browser or Hermes terminal.
4. Choose the display to control. Press **Start Mac control**, then show one
   open palm and hold it still for about 0.7 seconds. Control begins only after
   this deliberate hold. Use one hand; two detected hands pause recognition.
5. To finish, press **Escape** or **Stop / Esc**. The camera and input turn off.

Choose **English** or **Български** in either native window. Both windows and
the menu update together; the choice is remembered locally. **Click gesture**
selects **Index tap** (the default) or **Thumb + index pinch** in either window.
Changing it stops control and clears pending actions; start control again to
use the new choice. Both windows remember the selection.
**Pointer sensitivity** in the main window offers Low / Medium / High, saved
locally. Changing it stops control and clears pending actions. Medium is the
default and needs much less hand travel than the original absolute mapping.

For an index tap, hold your index up, move your whole hand to aim, then pause.
With your palm still, briefly bend only the index down and straighten it again.
The displayed target locks at the start of the curl and receives one click on the return.
The thumb does not participate. This is an air gesture inferred from camera
landmarks, not physical touch detection. The live panel shows the selected
gesture's three-step guide and an orange cue while a click is pending.

The window can remain behind your other apps. Closing it leaves the menu bar
controller running; the menu bar shows Off, Preview, Waiting or Control and
provides Stop and Quit. The helper is not installed as a login item.

The Live hand panel floats above other applications without taking keyboard
focus. Drag its title bar to move it. **Controls** reopens the main window;
**Show live hand** in that window or the menu bar reopens the camera panel.
Starting preview/control shows the panel and hides the large settings window.
Closing the Live hand panel stops camera and control. Stop/Escape also clears
the video and overlay instead of leaving the last camera image visible.

During Mac control, a mint ring follows the pointer across the selected display
and turns orange while a click pinch is pending. The ring passes mouse events
through to the app beneath it. It disappears when tracking or control is lost.
Partial landmarks can still be drawn for positioning feedback, but input uses
the higher confidence threshold. Pointing no longer requires the curled ring
and little fingers to remain visible. In pinch mode, an unclear thumb or middle
finger allows **movement only**. Index tapping does not require a visible thumb,
but does require reliable index geometry and a visible curled middle finger.
An unclear middle finger prevents either click gesture. The panel explains this
mode. A tracking gap freezes all input immediately. For up to 350 ms, a nearby
reacquisition can retain the armed state without another palm hold; it cannot
finish a click or send an action on the reacquisition frame. After a longer loss,
movement pauses and resumes once the user points steadily for 0.2 seconds, followed
by a fresh pointer dwell. Another open palm is not needed for ordinary tracking
loss. Explicit Stop, a held fist, multiple hands and tracker errors still clear
that resume intent. An outline alone does not mean input is armed.

## Gestures

To see the motions before trying real input, open **See the Mac gestures** in
the Portals page, or `/static/hand-demo.html?gesture=tap`. Gesture Lab animates an
illustrated hand with joint landmarks. Select a gesture and play it, pause,
scrub or choose a numbered step. It has English/Bulgarian instructions and
stops playback when hidden. Reduced-motion users get still poses by default.
The guide requests no camera permission and sends no input; the illustrations
are not recordings or evidence of live gesture accuracy.

For a physical trial, open `/static/gesture-test.html` on the localhost Portals
companion. It has an inert click target, a scrollable panel and visible counters.
Start Mac control, return to the test page and put the mouse/trackpad aside.
Test one gesture at a time, then press Escape. The page keeps results only in
memory, does not save or submit them, and resets on reload. Counters also accept
ordinary mouse/trackpad input, so they are evidence of delivery, not proof of
gesture origin. Focus loss alone does not prove an app switch; correlate it with
the visible app and native action label. The status banner requires the existing
localhost owner session; the inert test fields work without one.
The test page has its own English/Bulgarian selector. Its click instructions
follow the native controller's selected gesture through the owner-only status
route. Switching language keeps
the counters and translates the current event list; only the language preference
is stored locally. Reloading starts a fresh trial.

| Gesture | Result |
| --- | --- |
| Hold an open palm still for 0.7 seconds | Start control, or resume after a deliberate fist pause |
| After tracking is lost, point steadily again | Resume movement without repeating the palm gesture; pending clicks are cancelled |
| Extend the index finger; keep the other fingers comfortably curled | Move the pointer; hidden outer fingers do not interrupt it |
| Index tap: aim and pause, briefly bend the index down with palm still, then straighten | One left click at the early-locked pointer position |
| Optional pinch mode: after pointing steadily, touch index and thumb, then separate | One left click at the frozen pointer position |
| Extend index and middle fingers; curl ring and little fingers; move vertically | Scroll under the current pointer |
| Show an open palm, hold briefly, then swipe horizontally | Activate the next/previous running app |
| Hold a closed fist still for about one second | Park input; keep tracking for a new palm hold |
| Press Escape | Stop camera and all input |

App switching follows a stable alphabetical ring of running regular apps. It
is not the recent-app order of Cmd-Tab. Relax your fingers between swipes.
Index tap uses a short aiming history and palm-relative curl, so whole-hand
movement remains aiming. It needs a visible bend and return.
The bend can be modest and only needs a clear upward reversal rather than an
exact return to the starting finger angle; the time limit is now 1.0 second.
Tiny twitches, excessive palm movement, an unclear finger, tracking loss and mode changes
cancel the tap. Neither click style leaves a mouse button held down.
The click recognizer tolerates a brief (at most 0.3 seconds), tracked
transition from stable pointing through a closed/unclear pose while the thumb
approaches the index finger at the same palm position. It needs a visible
release within 0.75 seconds of the pinch; a long pinch,
large hand movement or tracking loss cancels it. It never holds a mouse button
down. Dragging, right click, double-click gestures, text entry and per-app
gesture bindings are not implemented.

The first pointing palm becomes the relative origin at screen center. Cursor
movement follows the palm (middle knuckle), not the curling fingertip, with
smoothing and a small palm-scaled dead band to suppress tremor. Slow corrections
use a lower gain; faster hand movement travels further. Low / Medium / High
set maximum gains of 2 / 4 / 6; slow precision movement uses 22.5% of those gains.
The transition is gradual. The range therefore depends on movement speed.
After tracking loss, the last cursor position is retained and a reacquired palm
becomes the new origin, avoiding a position jump. **Recenter** in the live panel
cancels pending actions and uses the next pointing hand position as screen
center. It does not send input on its own or activate stopped control.
The green marker in the preview still shows the detected index tip. Position the pointer over the intended scroll
area before raising two fingers. Performance and comfortable hand distance
still need testing across cameras, lighting conditions and users.

## Portals and Hermes integration

```text
/portals mac open     # open the native controller, with input off
/portals mac status   # permission and capture/control status
/portals mac stop     # stop native camera and input; leave its menu bar app open
```

The web page adds **Open Mac controller**, **Stop Mac control** and a status
display. Open immediately stops the browser camera. The page also polls native
capture status every two seconds while visible and stops its browser camera
when the native helper starts. Stop the native mode before enabling the Portals
camera. Tool handoff buttons remain usable with either camera mode off or on.

`/portals stop` stops only the browser companion. The native helper has an
independent lifecycle: use `/portals mac stop`, Escape, its Stop button or Quit
to finish Mac control. `/portals mac` commands work without the web server.

Hermes creates diagrams, checklists and calculators through the existing tools;
it can open/status/stop the helper through the slash command. The user starts
Mac input in the helper's window or menu. There is no model-accessible mouse,
keyboard or app-switching tool, and no remote endpoint that accepts gestures.
The phone's session cannot open, inspect or stop the native controller.

## Processing and stopping behavior

The native app uses AVFoundation for camera capture and Vision for hand
landmarks. Frames and landmarks are processed on this Mac and are not saved or
uploaded. It does not capture audio or screenshots, and has no network listener.
App names may appear in its local action label, but are not written to status.

The helper writes a private `status.json` and consumes a `stop.request` file in
`~/Library/Application Support/Hermes Portals Control`. Status contains a
heartbeat, permission/mode flags, the selected click gesture and process identity, not frames, landmarks,
app titles or keystrokes. This helper is shared by Hermes profiles on the same
Mac account; portable tool databases remain per profile. The companion exposes
only bounded status/open/stop operations to an authenticated localhost owner.

Missing hands or unclear core pointer landmarks freeze input and cancel pending
clicks. A gap longer than 350 ms pauses until fresh steady pointing; multiple
detected hands, invalid coordinates and tracker errors clear automatic resume
intent. A nearby brief reacquisition requires fresh gesture dwell and never
completes a previous click. Partial
movement-only samples cancel click readiness. Delayed frames
do not send input. Sleep, session changes, permission loss and display layout
changes stop capture/control. Changing the target display also stops it.
The key monitor checks Escape only; it does not record or transmit keystrokes.

See [validation](VALIDATION.md) for observed evidence and remaining physical
tests. Passing synthetic recognition tests does not establish real-world
accuracy or successful event delivery to other applications.
