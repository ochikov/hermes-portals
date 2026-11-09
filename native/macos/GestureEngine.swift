import Foundation

struct HandPoint: Equatable {
    var x: Double
    var y: Double
    func distance(to other: HandPoint) -> Double { hypot(x - other.x, y - other.y) }
    var valid: Bool { x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) }
}

enum HandPose: String { case point, aim, pinch, scroll, palm, fist, unknown }
enum HandJoint: CaseIterable {
    case wrist, thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

struct HandSample {
    var pointer: HandPoint
    var palm: HandPoint
    var pinch: Double
    var pose: HandPose
    var indexExtension: Double? = nil
    var palmScale: Double = 0.2
    var tapEligible = false
    var valid: Bool {
        pointer.valid && palm.valid && pinch.isFinite && pinch >= 0 &&
        palmScale.isFinite && palmScale >= 0.025 &&
        (indexExtension.map { $0.isFinite && $0 > 0 } ?? true)
    }

    static func recognize(_ points: [HandJoint: HandPoint]) -> HandSample? {
        // Curled ring/little fingers are often occluded. They are not required
        // to aim; never substitute low-confidence coordinates for a lost tip.
        let required: [HandJoint] = [.wrist, .middleMCP, .indexPIP, .indexTip]
        guard required.allSatisfy({ points[$0]?.valid == true }),
              let wrist = points[.wrist], let palm = points[.middleMCP],
              let tip = points[.indexTip] else { return nil }
        let scale = wrist.distance(to: palm)
        guard scale >= 0.025 else { return nil }
        func extended(_ tip: HandJoint, _ pip: HandJoint) -> Bool? {
            guard let end = points[tip], let bend = points[pip], end.valid, bend.valid else { return nil }
            return end.distance(to: wrist) > bend.distance(to: wrist) * 1.16
        }
        let index = extended(.indexTip, .indexPIP), middle = extended(.middleTip, .middlePIP)
        let ring = extended(.ringTip, .ringPIP), little = extended(.littleTip, .littlePIP)
        let thumb = points[.thumbTip].flatMap { $0.valid ? $0 : nil }
        let pinch = thumb.map { tip.distance(to: $0) / scale } ?? 1
        let pose: HandPose
        if index == true && middle == true && ring == true && little == true && thumb != nil && pinch > 0.48 { pose = .palm }
        else if index == true && middle == true && ring == false && little == false { pose = .scroll }
        else if thumb != nil && middle == false && ring != true && little != true && pinch < 0.30 { pose = .pinch }
        else if index == true && middle == false && ring != true && little != true && thumb != nil { pose = .point }
        else if index == true && middle != true { pose = .aim }
        else if index == false && middle == false && ring == false && little == false { pose = .fist }
        else { pose = .unknown }
        let indexBase = points[.indexPIP]!.distance(to: wrist)
        guard indexBase > 0.001 else { return nil }
        return HandSample(pointer: tip, palm: palm, pinch: pinch, pose: pose,
            indexExtension: tip.distance(to: wrist) / indexBase, palmScale: scale,
            tapEligible: middle == false && ring != true && little != true)
    }
}

enum MacGestureAction: Equatable {
    case move(HandPoint)
    case click(HandPoint)
    case scroll(Int32)
    case switchApp(Int)
}

enum ClickGesture: String { case indexTap, pinch }

/// Pure recognizer; no camera, permissions, events, files, network or timers.
/// Only a deliberate palm hold arms it. Missing/invalid frames cancel clicks.
/// A brief gap freezes input; a nearby reacquisition can retain the armed state.
final class MacGestureEngine {
    var clickGesture: ClickGesture = .pinch { didSet { reset() } }
    // Maximum gain for broad, quick movements; slow corrections use lower gain.
    // The first pointing palm anchors at screen center wherever it is held.
    var pointerGain = 4.0 { didSet { reset() } }
    private(set) var armed = false
    private(set) var message = "Hold an open palm still to take control"
    private var previousTime: Double?
    private var lastTrackedTime: Double?
    private var lastTrackedPalm: HandPoint?
    private var recovering = false
    private var resumeAfterTrackingLoss = false
    private var pose: HandPose = .unknown
    private var poseSince = 0.0
    private var anchor: HandPoint?
    private var cursor: HandPoint?
    private var filteredPalm: HandPoint?
    private var acceptedPalm: HandPoint?
    private var pointerTime: Double?
    private var pointingSince: Double?
    private var lastPointTime: Double?
    private var lastPointPalm: HandPoint?
    private var pinchSince: Double?
    private var pinchPalm: HandPoint?
    private var clickAt: HandPoint?
    private struct AimFrame { var time: Double; var sample: HandSample; var cursor: HandPoint }
    private var aimHistory: [AimFrame] = []
    private var tapReference: AimFrame?
    private var tapSince: Double?
    private var tapBent = false
    private var tapPeakDown = 0.0
    private var tapMinExtension = 0.0
    private var tapAt: HandPoint?
    private var clickCooldown = 0.0
    private var switchCooldown = 0.0
    private var swiped = false
    private var scrollY: Double?
    private var scrollRemainder = 0.0
    var feedbackPoint: HandPoint? { armed ? (tapAt ?? clickAt ?? cursor) : nil }
    var pinchPending: Bool { pinchSince != nil }
    var tapPending: Bool { tapSince != nil }
    var clickPending: Bool { pinchPending || tapPending }

    func reset() {
        armed = false; previousTime = nil; pose = .unknown; poseSince = 0
        lastTrackedTime = nil; lastTrackedPalm = nil; recovering = false
        resumeAfterTrackingLoss = false
        anchor = nil; cursor = nil; pointingSince = nil; lastPointTime = nil; lastPointPalm = nil; cancelPinch()
        filteredPalm = nil; acceptedPalm = nil; pointerTime = nil
        cancelTap(); aimHistory.removeAll()
        clickCooldown = 0; switchCooldown = 0; swiped = false
        scrollY = nil; scrollRemainder = 0
        message = "Hold an open palm still to take control"
    }

    /// Preserve the user's activation intent through occlusion, while clearing
    /// every pending action. A fresh, steady pointing pose is needed to resume.
    /// Explicit reset (Stop, fist, permissions, two hands) still requires a palm.
    func pauseTracking() {
        let mayResume = armed || resumeAfterTrackingLoss
        let position = tapAt ?? clickAt ?? cursor
        reset(); resumeAfterTrackingLoss = mayResume
        cursor = position
        message = mayResume ? "Tracking paused · point steadily to resume" : "Hold an open palm still to take control"
    }

    /// Only clears/reanchors state; this method never sends a Mac input event.
    func recenterPointer() {
        cancelPinch(); cancelTap(); pointingSince = nil; lastPointTime = nil; lastPointPalm = nil
        filteredPalm = nil; acceptedPalm = nil; pointerTime = nil; cursor = nil
        pose = .unknown; anchor = nil; scrollY = nil; scrollRemainder = 0
        message = "Point comfortably · cursor will start at the center"
    }

    private func reanchorPointer(_ palm: HandPoint, time: Double) {
        filteredPalm = palm; acceptedPalm = palm; pointerTime = time
    }

    private func cancelPinch() { pinchSince = nil; pinchPalm = nil; clickAt = nil }
    private func cancelTap() {
        tapSince = nil; tapReference = nil; tapAt = nil; tapBent = false
        tapPeakDown = 0; tapMinExtension = 0; aimHistory.removeAll()
    }

    /// Finger curl is measured relative to the palm, so moving the whole hand
    /// is aiming, not tapping. Freeze the displayed cursor at the first small
    /// downward curl; historical finger geometry is not a historical target.
    private func indexTap(_ sample: HandSample, time: Double) -> [MacGestureAction]? {
        if let started = tapSince, let reference = tapReference {
            let base = reference.sample
            guard sample.tapEligible, let extensionNow = sample.indexExtension,
                  let extensionBefore = base.indexExtension, time - started <= 1.0,
                  sample.palm.distance(to: base.palm) / base.palmScale < 0.30,
                  sample.pose != .scroll, sample.pose != .palm else {
                cancelTap(); pointingSince = nil; clickCooldown = time + 0.35
                reanchorPointer(sample.palm, time: time)
                message = "Tap cancelled · point at the target again"; return []
            }
            let down = ((sample.pointer.y - sample.palm.y) - (base.pointer.y - base.palm.y)) / base.palmScale
            tapPeakDown = max(tapPeakDown, down)
            tapMinExtension = min(tapMinExtension, extensionNow)
            if extensionBefore - extensionNow >= 0.14 && down >= 0.12 { tapBent = true }
            // A clear upward return is sufficient; do not demand an exact
            // reconstruction of the original finger angle after every tap.
            let returning = tapPeakDown - down >= 0.08 && extensionNow - tapMinExtension >= 0.08 && extensionNow >= 1.15
            let returnedWithoutBend = !tapBent && extensionNow >= extensionBefore - 0.05 && down < 0.05
            if (tapBent && returning) || returnedWithoutBend {
                let target = tapAt
                let valid = tapBent && time - started >= 0.08 && (sample.pose == .point || sample.pose == .aim)
                cancelTap(); pointingSince = nil; clickCooldown = time + 0.45
                reanchorPointer(sample.palm, time: time)
                message = valid ? "Click" : "Tap too small or brief · no click"
                return valid && target != nil ? [.click(target!)] : []
            }
            message = tapBent ? "Straighten your index finger → click" : "Cursor locked · bend only your index finger"
            return []
        }
        aimHistory.removeAll { time - $0.time > 0.25 }
        guard time >= clickCooldown, let pointing = pointingSince, time - pointing >= 0.15,
              sample.tapEligible, let extensionNow = sample.indexExtension,
              let reference = aimHistory.first, time - reference.time >= 0.10,
              let extensionBefore = reference.sample.indexExtension, extensionBefore >= 1.2 else { return nil }
        let base = reference.sample
        let down = ((sample.pointer.y - sample.palm.y) - (base.pointer.y - base.palm.y)) / base.palmScale
        guard sample.palm.distance(to: base.palm) / base.palmScale < 0.20,
              down >= 0.07, extensionBefore - extensionNow >= 0.06,
              sample.pose != .scroll, sample.pose != .palm else { return nil }
        let target = cursor ?? reference.cursor
        tapSince = time; tapReference = reference; tapAt = target; cursor = target
        tapPeakDown = down; tapMinExtension = extensionNow
        tapBent = extensionBefore - extensionNow >= 0.14 && down >= 0.12
        pointingSince = nil
        message = tapBent ? "Straighten your index finger → click" : "Cursor locked · bend only your index finger"
        return [.move(target)]
    }
    private func mapped(_ sample: HandSample, time: Double) -> HandPoint {
        let origin = cursor ?? HandPoint(x: 0.5, y: 0.5)
        guard let previous = filteredPalm, let accepted = acceptedPalm, let last = pointerTime else {
            reanchorPointer(sample.palm, time: time); return origin
        }
        let dt = min(0.15, max(0.015, time - last))
        pointerTime = time
        // Smooth camera noise before velocity estimation. A small palm-scaled
        // dead band holds the cursor still instead of amplifying hand tremor.
        let alpha = 1 - exp(-dt / 0.065)
        let filtered = HandPoint(x: previous.x + alpha * (sample.palm.x - previous.x),
                                 y: previous.y + alpha * (sample.palm.y - previous.y))
        filteredPalm = filtered
        let distance = filtered.distance(to: accepted)
        let deadBand = min(0.006, max(0.0015, sample.palmScale * 0.018))
        guard distance > deadBand else { return origin }
        let fraction = (distance - deadBand) / distance
        let dx = (filtered.x - accepted.x) * fraction, dy = (filtered.y - accepted.y) * fraction
        acceptedPalm = HandPoint(x: accepted.x + dx, y: accepted.y + dy)
        let speed = hypot(dx, dy) / dt
        let maximum = pointerGain.isFinite ? min(8, max(1, pointerGain)) : 4
        let blend = min(1, max(0, (speed - 0.025) / 0.20))
        let gain = maximum * (0.225 + 0.775 * blend * blend * (3 - 2 * blend))
        return HandPoint(x: min(1, max(0, origin.x + dx * gain)),
                         y: min(1, max(0, origin.y + dy * gain)))
    }

    func update(_ sample: HandSample?, time: Double, enabled: Bool, allowRecovery: Bool = true) -> [MacGestureAction] {
        guard enabled, time.isFinite else {
            reset(); message = enabled ? "Hand not clear · hold an open palm to resume" : "Preview only · Mac input is off"
            return []
        }
        if let previous = previousTime {
            if time <= previous { reset() }
            else if time - previous > 0.4 { pauseTracking() }
        }
        previousTime = time
        guard let sample = sample, sample.valid else {
            // Vision can miss a frame even with a stationary visible hand.
            // Keep no pending action, emit nothing and never extrapolate motion.
            if sample == nil, allowRecovery, armed,
               let last = lastTrackedTime, time - last <= 0.35 {
                recovering = true; cancelPinch(); cancelTap(); pointingSince = nil
                lastPointTime = nil; lastPointPalm = nil; scrollY = nil; scrollRemainder = 0
                message = "Tracking briefly unclear · keep your hand in view"
                return []
            }
            if sample == nil && allowRecovery { pauseTracking() }
            else { reset(); message = "Hand not clear · hold an open palm to resume" }
            return []
        }
        if recovering {
            let nearby = lastTrackedPalm.map { sample.palm.distance(to: $0) < 0.12 } == true
            let brief = lastTrackedTime.map { time - $0 <= 0.35 } == true
            if nearby && brief {
                recovering = false; lastTrackedTime = time; lastTrackedPalm = sample.palm
                // Reacquisition itself never clicks, scrolls or switches apps.
                // Start all gesture dwell/readiness again, retaining only cursor smoothing.
                pose = sample.pose; poseSince = time; anchor = sample.palm; swiped = false
                reanchorPointer(sample.palm, time: time)
                message = "Tracking restored · point to continue"
                return []
            }
            pauseTracking(); previousTime = time
        }
        lastTrackedTime = time; lastTrackedPalm = sample.palm
        if !armed {
            if resumeAfterTrackingLoss && (sample.pose == .point || sample.pose == .aim) {
                if (pose != .point && pose != .aim) || anchor == nil || sample.palm.distance(to: anchor!) > 0.06 {
                    anchor = sample.palm; poseSince = time
                }
                pose = sample.pose
                if time - poseSince >= 0.20 {
                    armed = true; resumeAfterTrackingLoss = false; poseSince = time
                    reanchorPointer(sample.palm, time: time)
                    message = "Tracking restored · point to continue"
                } else { message = "Keep pointing · resuming movement…" }
                return []
            }
            if sample.pose == .palm {
                if pose != .palm || anchor == nil || sample.palm.distance(to: anchor!) > 0.06 {
                    anchor = sample.palm; poseSince = time
                }
                pose = .palm
                if time - poseSince >= 0.7 {
                    armed = true; resumeAfterTrackingLoss = false; poseSince = time; anchor = sample.palm
                    message = "Ready · point, pinch, two fingers or palm swipe"
                } else { message = "Hold your palm still…" }
            } else {
                pose = .unknown; anchor = nil
                message = resumeAfterTrackingLoss ? "Tracking paused · point steadily to resume" : "Hold an open palm still for a moment"
            }
            return []
        }

        if clickGesture == .indexTap, let actions = indexTap(sample, time: time) { return actions }
        // A click can only begin after stable pointing and completes on a visible release.
        // Pointer is frozen during the pinch to prevent thumb/index convergence moving it.
        if let started = pinchSince {
            guard time - started <= 0.75,
                  sample.palm.distance(to: pinchPalm!) < 0.10,
                  sample.pose != .palm, sample.pose != .scroll, sample.pose != .aim else {
                cancelPinch(); pointingSince = nil; message = "Pinch cancelled"; return []
            }
            if sample.pinch > 0.48 {
                let target = clickAt
                let valid = time - started >= 0.09 && sample.pose == .point
                cancelPinch(); pointingSince = nil; clickCooldown = time + 0.45
                message = valid ? "Click" : "Pinch too brief · no click"
                return valid && target != nil ? [.click(target!)] : []
            }
            message = "Release pinch to click"; return []
        }
        // A bending index can briefly look like a fist before thumb and tip meet.
        // Preserve readiness only for a short, visible approach at the same palm.
        let approaching = (sample.pose == .fist || sample.pose == .unknown) && sample.pinch < 0.70 &&
                lastPointTime.map { time - $0 <= 0.30 } == true &&
                lastPointPalm.map { sample.palm.distance(to: $0) < 0.08 } == true
        let tapPoint = clickGesture == .indexTap && sample.pose == .aim && sample.tapEligible
        if sample.pose != .point && !tapPoint && sample.pose != .pinch && !approaching { pointingSince = nil }
        if sample.pose != pose {
            let continuingPointer = (pose == .point || pose == .aim) && (sample.pose == .point || sample.pose == .aim)
            if !continuingPointer && (sample.pose == .point || sample.pose == .aim) { reanchorPointer(sample.palm, time: time) }
            pose = sample.pose
            if !continuingPointer { poseSince = time }
            anchor = sample.palm
            scrollY = nil; scrollRemainder = 0; swiped = false
        }
        switch sample.pose {
        case .point, .aim:
            if sample.pose == .point || tapPoint {
                if pointingSince == nil { pointingSince = time }
                lastPointTime = time; lastPointPalm = sample.palm
            }
            cursor = mapped(sample, time: time)
            if clickGesture == .indexTap {
                message = sample.tapEligible ? "Move your hand to aim · bend your index to tap" : "Moving only · keep the other fingers curled to tap"
                if sample.tapEligible, let extensionNow = sample.indexExtension, extensionNow >= 1.2 {
                    aimHistory.append(AimFrame(time: time, sample: sample, cursor: cursor!))
                    if aimHistory.count > 8 { aimHistory.removeFirst(aimHistory.count - 8) }
                }
            } else {
                message = sample.pose == .aim ? "Moving only · show your thumb and curl the other fingers to click" : "Point · touch thumb to index, then separate to click"
            }
            return time - poseSince >= 0.12 ? [.move(cursor!)] : []
        case .pinch:
            guard clickGesture == .pinch else {
                pointingSince = nil; aimHistory.removeAll()
                message = "Bend your index, then straighten to tap"; return []
            }
            if let pointing = pointingSince, time - pointing >= 0.15,
               lastPointTime.map({ time - $0 <= 0.30 }) == true,
               time >= clickCooldown, let cursor = cursor {
                pinchSince = time; pinchPalm = sample.palm; clickAt = cursor
                message = "Release pinch to click"
            } else { message = "Point first, then pinch" }
            pointingSince = nil
        case .scroll:
            message = "Two fingers · move up or down to scroll"
            guard time - poseSince >= 0.18 else { return [] }
            defer { scrollY = sample.palm.y }
            guard let previous = scrollY else { return [] }
            let delta = sample.palm.y - previous
            // An abrupt jump is a reacquisition, not a scroll command.
            guard abs(delta) < 0.12 else { scrollRemainder = 0; return [] }
            scrollRemainder += max(-55, min(55, -delta * 1100))
            let amount = Int32(scrollRemainder)
            scrollRemainder -= Double(amount)
            return amount == 0 ? [] : [.scroll(amount)]
        case .palm:
            message = swiped ? "App switched · relax your fingers before another swipe" : "Open palm · hold briefly, then swipe left or right"
            guard !swiped, time >= switchCooldown, let start = anchor else { return [] }
            let duration = time - poseSince
            if duration < 0.18 && sample.palm.distance(to: start) > 0.05 {
                anchor = sample.palm; poseSince = time; return []
            }
            if duration > 1.1 { anchor = sample.palm; poseSince = time; return [] }
            if duration >= 0.18 && abs(sample.palm.x - start.x) > 0.23 && abs(sample.palm.y - start.y) < 0.16 {
                swiped = true; switchCooldown = time + 1.1
                return [.switchApp(sample.palm.x > start.x ? 1 : -1)]
            }
        case .fist:
            message = "Fist · hold still for one second to pause"
            if let start = anchor, sample.palm.distance(to: start) > 0.06 {
                anchor = sample.palm; poseSince = time
            }
            if time - poseSince >= 0.75 { reset(); message = "Parked · hold an open palm to resume" }
        case .unknown:
            message = "Show a clear pointing, two-finger or open-palm pose"
        }
        return []
    }
}
