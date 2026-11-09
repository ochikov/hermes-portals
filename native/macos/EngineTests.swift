import Foundation

/// Runs in the shipped binary with --self-test before NSApplication is created.
/// No permissions are requested and no mouse/keyboard/application events are sent.
func runEngineTests() -> Int32 {
    var checks = 0
    func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    func sample(_ pose: HandPose, x: Double = 0.5, y: Double = 0.5, pinch: Double = 0.8) -> HandSample {
        HandSample(pointer: HandPoint(x: x, y: y), palm: HandPoint(x: x, y: y), pinch: pinch, pose: pose)
    }
    func armed(_ gesture: ClickGesture = .pinch) -> MacGestureEngine {
        let engine = MacGestureEngine()
        engine.clickGesture = gesture
        for i in 0...8 { _ = engine.update(sample(.palm), time: Double(i) / 10, enabled: true) }
        expect(engine.armed, "palm hold arms control")
        return engine
    }
    let preview = MacGestureEngine()
    for i in 0...20 { expect(preview.update(sample(.point), time: Double(i) / 10, enabled: false).isEmpty, "preview never emits input") }
    expect(!preview.armed, "preview cannot arm")
    let click = armed()
    _ = click.update(sample(.point), time: 0.9, enabled: true)
    _ = click.update(sample(.point), time: 1.1, enabled: true)
    _ = click.update(sample(.pinch, pinch: 0.1), time: 1.2, enabled: true)
    let clicked = click.update(sample(.point), time: 1.4, enabled: true)
    expect(clicked == [.click(HandPoint(x: 0.5, y: 0.5))], "visible deliberate pinch/release clicks at frozen point")
    expect(!click.update(sample(.point), time: 1.5, enabled: true).contains(.click(HandPoint(x: 0.5, y: 0.5))), "no duplicate click")
    for transition in [HandPose.fist, HandPose.unknown] {
        let engine = armed()
        _ = engine.update(sample(.point), time: 0.9, enabled: true)
        _ = engine.update(sample(.point), time: 1.1, enabled: true)
        _ = engine.update(sample(transition, pinch: 0.5), time: 1.17, enabled: true)
        _ = engine.update(sample(.pinch, pinch: 0.1), time: 1.24, enabled: true)
        expect(engine.pinchPending, "brief visible \(transition) approach can enter pinch")
        expect(engine.feedbackPoint == HandPoint(x: 0.5, y: 0.5), "pinch feedback stays at the frozen pointer")
        expect(engine.update(sample(.point), time: 1.4, enabled: true) == [.click(HandPoint(x: 0.5, y: 0.5))], "visible \(transition) approach completes one click")
    }
    for failure in ["slow", "moved", "missing", "open"] {
        let engine = armed()
        _ = engine.update(sample(.point), time: 0.9, enabled: true)
        _ = engine.update(sample(.point), time: 1.1, enabled: true)
        if failure == "slow" {
            _ = engine.update(sample(.fist, pinch: 0.5), time: 1.2, enabled: true)
            _ = engine.update(sample(.fist, pinch: 0.5), time: 1.45, enabled: true)
        } else if failure == "moved" {
            _ = engine.update(sample(.fist, x: 0.7, pinch: 0.5), time: 1.2, enabled: true)
        } else if failure == "missing" {
            _ = engine.update(nil, time: 1.2, enabled: true)
        } else {
            _ = engine.update(sample(.unknown, pinch: 0.9), time: 1.2, enabled: true)
        }
        _ = engine.update(sample(.pinch, pinch: 0.1), time: 1.5, enabled: true)
        expect(!engine.pinchPending, "\(failure) approach does not retain click readiness")
        expect(!engine.update(sample(.point), time: 1.65, enabled: true).contains(where: { if case .click = $0 { return true }; return false }), "\(failure) approach never clicks")
    }
    for failure in ["lost", "long", "move", "brief"] {
        let engine = armed()
        _ = engine.update(sample(.point), time: 0.9, enabled: true)
        _ = engine.update(sample(.point), time: 1.1, enabled: true)
        _ = engine.update(sample(.pinch, pinch: 0.1), time: 1.2, enabled: true)
        var actions: [MacGestureAction] = []
        if failure == "lost" { _ = engine.update(nil, time: 1.3, enabled: true); actions = engine.update(sample(.point), time: 1.4, enabled: true) }
        if failure == "move" { actions = engine.update(sample(.point, x: 0.8), time: 1.4, enabled: true) }
        if failure == "brief" { actions = engine.update(sample(.point), time: 1.24, enabled: true) }
        if failure == "long" {
            for i in 13...20 { actions += engine.update(sample(.pinch, pinch: 0.1), time: Double(i) / 10, enabled: true) }
            actions += engine.update(sample(.point), time: 2.1, enabled: true)
        }
        expect(!actions.contains(where: { if case .click = $0 { return true }; return false }), "\(failure) cancels click")
    }
    let scroll = armed()
    _ = scroll.update(sample(.scroll), time: 0.9, enabled: true)
    _ = scroll.update(sample(.scroll), time: 1.1, enabled: true)
    let scrolled = scroll.update(sample(.scroll, y: 0.55), time: 1.2, enabled: true)
    expect(scrolled == [.scroll(-55)], "downward hand movement scrolls down with a per-frame bound")
    expect(scroll.update(sample(.scroll, y: 0.9), time: 1.3, enabled: true).isEmpty, "jump does not scroll")
    let swipe = armed()
    _ = swipe.update(sample(.palm), time: 0.9, enabled: true)
    expect(swipe.update(sample(.palm, x: 0.8), time: 1.1, enabled: true) == [.switchApp(1)], "deliberate palm swipe switches once")
    expect(swipe.update(sample(.palm, x: 0.2), time: 1.2, enabled: true).isEmpty, "held palm cannot switch repeatedly")
    _ = swipe.update(sample(.fist), time: 1.3, enabled: true)
    _ = swipe.update(sample(.fist), time: 1.6, enabled: true)
    _ = swipe.update(sample(.fist), time: 1.8, enabled: true)
    expect(swipe.armed, "brief fist does not park control")
    _ = swipe.update(sample(.fist), time: 2.1, enabled: true)
    expect(!swipe.armed, "held fist parks input")
    let stale = armed()
    expect(stale.update(sample(.point), time: 10, enabled: true).isEmpty && !stale.armed, "stalled frame stream disarms")
    let invalid = armed()
    expect(invalid.update(sample(.point, x: .nan), time: 0.9, enabled: true).isEmpty && !invalid.armed, "invalid coordinates disarm")
    let gap = armed()
    _ = gap.update(sample(.point), time: 0.9, enabled: true)
    _ = gap.update(sample(.point), time: 1.1, enabled: true)
    expect(gap.update(nil, time: 1.2, enabled: true).isEmpty && gap.armed, "brief dropout freezes input without requiring another palm hold")
    expect(gap.update(sample(.point, x: 0.53), time: 1.3, enabled: true).isEmpty && gap.armed, "nearby reacquisition emits no action")
    expect(gap.update(sample(.point, x: 0.53), time: 1.45, enabled: true).contains(where: { if case .move = $0 { return true }; return false }), "pointer resumes after a brief gap and fresh dwell")
    for recoveryPose in [HandPose.pinch, .scroll, .palm] {
        let recovery = armed()
        _ = recovery.update(sample(.point), time: 0.9, enabled: true)
        _ = recovery.update(sample(.point), time: 1.1, enabled: true)
        _ = recovery.update(nil, time: 1.2, enabled: true)
        expect(recovery.update(sample(recoveryPose, pinch: 0.1), time: 1.3, enabled: true).isEmpty, "reacquisition as \(recoveryPose) never performs an action")
        expect(!recovery.pinchPending, "dropout discards click readiness")
    }
    let longGap = armed()
    _ = longGap.update(nil, time: 1.0, enabled: true)
    expect(longGap.update(nil, time: 1.2, enabled: true).isEmpty && !longGap.armed, "loss beyond 350ms disarms")
    let distant = armed()
    _ = distant.update(nil, time: 0.9, enabled: true)
    expect(distant.update(sample(.point, x: 0.8), time: 1.0, enabled: true).isEmpty && !distant.armed, "distant hand cannot inherit armed state")
    let ambiguous = armed()
    expect(ambiguous.update(nil, time: 0.9, enabled: true, allowRecovery: false).isEmpty && !ambiguous.armed, "two hands or tracker errors disarm immediately")
    for interruption in ["long occlusion", "delayed frame", "watchdog"] {
        let resume = armed()
        _ = resume.update(sample(.point), time: 0.9, enabled: true)
        _ = resume.update(sample(.point), time: 1.1, enabled: true)
        _ = resume.update(sample(.pinch, pinch: 0.1), time: 1.2, enabled: true)
        if interruption == "long occlusion" {
            for i in 13...25 { expect(resume.update(nil, time: Double(i)/10, enabled: true).isEmpty, "occlusion emits no input") }
        } else if interruption == "watchdog" { resume.pauseTracking(); resume.pauseTracking() }
        expect(resume.update(sample(.point), time: 3.0, enabled: true).isEmpty && !resume.armed, "\(interruption): reacquisition waits for steady pointing")
        expect(resume.update(sample(.point), time: 3.25, enabled: true).isEmpty && resume.armed, "\(interruption): stable pointing resumes without an open palm or an action")
        expect(resume.update(sample(.point), time: 3.40, enabled: true).contains(where: { if case .move = $0 { return true }; return false }), "\(interruption): pointer moves after fresh dwell")
        expect(!resume.pinchPending, "\(interruption): old click is cancelled")
    }
    let parked = armed()
    _ = parked.update(sample(.fist), time: 0.9, enabled: true)
    _ = parked.update(sample(.fist), time: 1.2, enabled: true)
    _ = parked.update(sample(.fist), time: 1.4, enabled: true)
    _ = parked.update(sample(.fist), time: 1.7, enabled: true)
    _ = parked.update(nil, time: 1.8, enabled: true)
    _ = parked.update(sample(.point), time: 1.9, enabled: true)
    _ = parked.update(sample(.point), time: 2.2, enabled: true)
    expect(!parked.armed, "explicit fist pause cannot resume by pointing")
    let passingFist = armed()
    for i in 0...10 { _ = passingFist.update(sample(.fist, x: 0.3 + Double(i)*0.03), time: 0.9 + Double(i)*0.1, enabled: true) }
    expect(passingFist.armed, "a moving fist-shaped hand does not accidentally park control")
    let stopped = armed()
    _ = stopped.update(nil, time: 0.9, enabled: false)
    _ = stopped.update(sample(.point), time: 1.0, enabled: true)
    _ = stopped.update(sample(.point), time: 1.3, enabled: true)
    expect(!stopped.armed, "Stop clears automatic resume intent")
    let direct = armed()
    expect(direct.update(sample(.pinch, pinch: 0.1), time: 0.9, enabled: true).isEmpty, "pinch without pointing does not click")
    expect(HandSample.recognize([:]) == nil, "partial landmarks are rejected")
    var points: [HandJoint: HandPoint] = [
        .wrist: HandPoint(x: 0.5, y: 0.8), .middleMCP: HandPoint(x: 0.5, y: 0.6),
        .indexPIP: HandPoint(x: 0.5, y: 0.45), .indexTip: HandPoint(x: 0.5, y: 0.2),
        .thumbTip: HandPoint(x: 0.15, y: 0.5), .middlePIP: HandPoint(x: 0.6, y: 0.5),
        .middleTip: HandPoint(x: 0.55, y: 0.7), .ringPIP: HandPoint(x: 0.7, y: 0.55),
        .ringTip: HandPoint(x: 0.55, y: 0.7), .littlePIP: HandPoint(x: 0.8, y: 0.6),
        .littleTip: HandPoint(x: 0.55, y: 0.7),
    ]
    expect(HandSample.recognize(points)?.pose == .point, "extended index classifies as pointing")
    var hiddenCurled = points
    for joint in [HandJoint.ringPIP, .ringTip, .littlePIP, .littleTip] { hiddenCurled.removeValue(forKey: joint) }
    expect(HandSample.recognize(hiddenCurled)?.pose == .point, "occluded curled ring/little fingers do not interrupt pointing")
    hiddenCurled[.thumbTip] = HandPoint(x: 0.51, y: 0.2)
    expect(HandSample.recognize(hiddenCurled)?.pose == .pinch, "visible thumb/index pinch works with occluded outer fingers")
    hiddenCurled.removeValue(forKey: .thumbTip)
    expect(HandSample.recognize(hiddenCurled)?.pose == .aim, "hidden thumb allows movement only")
    expect(HandSample.recognize(hiddenCurled)?.tapEligible == true, "index tapping does not require the thumb")
    hiddenCurled.removeValue(forKey: .middleTip)
    expect(HandSample.recognize(hiddenCurled)?.pose == .aim, "uncertain curled middle finger allows movement only")
    expect(HandSample.recognize(hiddenCurled)?.tapEligible == false, "unclear middle finger cannot establish tap readiness")
    hiddenCurled.removeValue(forKey: .indexTip)
    expect(HandSample.recognize(hiddenCurled) == nil, "missing index tip never fabricates pointer coordinates")
    let moving = armed()
    _ = moving.update(sample(.point), time: 0.9, enabled: true)
    _ = moving.update(sample(.point), time: 1.1, enabled: true)
    expect(moving.update(sample(.aim, x: 0.6), time: 1.15, enabled: true).contains(where: { if case .move = $0 { return true }; return false }), "move-only transition does not restart pointer dwell")
    _ = moving.update(sample(.pinch, pinch: 0.1), time: 1.2, enabled: true)
    expect(!moving.pinchPending, "move-only tracking cannot establish click readiness")
    let interrupted = armed()
    _ = interrupted.update(sample(.point), time: 0.9, enabled: true)
    _ = interrupted.update(sample(.point), time: 1.1, enabled: true)
    _ = interrupted.update(sample(.pinch, pinch: 0.1), time: 1.2, enabled: true)
    expect(interrupted.update(sample(.aim), time: 1.3, enabled: true).isEmpty && !interrupted.pinchPending, "uncertain thumb on release cancels pending click")
    expect(!interrupted.update(sample(.point), time: 1.4, enabled: true).contains(where: { if case .click = $0 { return true }; return false }), "reacquiring thumb cannot complete cancelled click")
    points[.thumbTip] = HandPoint(x: 0.51, y: 0.2)
    expect(HandSample.recognize(points)?.pose == .pinch, "palm-normalized thumb/index distance classifies pinch")
    points[.thumbTip] = HandPoint(x: 0.15, y: 0.5)
    points[.middleTip] = HandPoint(x: 0.6, y: 0.2)
    expect(HandSample.recognize(points)?.pose == .scroll, "two extended fingers classify as scrolling")
    var partialScroll = points; partialScroll.removeValue(forKey: .littleTip)
    expect(HandSample.recognize(partialScroll)?.pose != .scroll, "uncertain outer fingers cannot trigger scrolling")
    points[.ringTip] = HandPoint(x: 0.7, y: 0.25); points[.littleTip] = HandPoint(x: 0.8, y: 0.3)
    expect(HandSample.recognize(points)?.pose == .palm, "four extended fingers classify as open palm")
    points.removeValue(forKey: .ringTip)
    expect(HandSample.recognize(points)?.pose != .palm, "partial palm cannot arm or switch apps")

    func tapSample(_ extensionValue: Double = 1.7, down: Double = 0, palmX: Double = 0.5,
                   palmY: Double = 0.7, pose: HandPose = .point, eligible: Bool = true) -> HandSample {
        HandSample(pointer: HandPoint(x: palmX, y: palmY - 0.2 + down), palm: HandPoint(x: palmX, y: palmY),
                   pinch: 0.8, pose: pose, indexExtension: extensionValue, palmScale: 0.2, tapEligible: eligible)
    }
    func readyTap(_ pose: HandPose = .point) -> MacGestureEngine {
        let engine = armed(.indexTap)
        for time in [0.9, 1.0, 1.1, 1.15] { _ = engine.update(tapSample(pose: pose), time: time, enabled: true) }
        return engine
    }
    for pointing in [HandPose.point, .aim] {
        let tap = readyTap(pointing)
        let frozen = tap.feedbackPoint!
        let onset = tap.update(tapSample(1.62, down: 0.02, pose: pointing), time: 1.2, enabled: true)
        expect(tap.tapPending && onset == [.move(frozen)], "\(pointing): early curl locks the settled target before the finger moves far")
        expect(tap.update(tapSample(1.3, down: 0.08, pose: .unknown), time: 1.3, enabled: true).isEmpty, "bending does not move or click")
        expect(tap.feedbackPoint == frozen, "cursor remains at the original target during the bend")
        expect(tap.update(tapSample(pose: pointing), time: 1.45, enabled: true) == [.click(frozen)], "straightening the index sends one click at the locked position")
        expect(!tap.clickPending, "completed tap clears pending input")
        expect(!tap.update(tapSample(pose: pointing), time: 1.5, enabled: true).contains(where: { if case .click = $0 { return true }; return false }), "tap cannot repeat on held release")
    }
    for failure in ["small", "lost", "moved", "long", "unclear", "scroll"] {
        let tap = readyTap()
        _ = tap.update(tapSample(1.62, down: 0.02), time: 1.2, enabled: true)
        var actions: [MacGestureAction] = []
        if failure == "small" { actions += tap.update(tapSample(), time: 1.3, enabled: true) }
        else if failure == "lost" { actions += tap.update(nil, time: 1.3, enabled: true) }
        else if failure == "moved" { actions += tap.update(tapSample(1.3, down: 0.08, palmX: 0.7), time: 1.3, enabled: true) }
        else if failure == "unclear" { actions += tap.update(tapSample(1.3, down: 0.08, eligible: false), time: 1.3, enabled: true) }
        else if failure == "scroll" { actions += tap.update(tapSample(1.3, down: 0.08, pose: .scroll), time: 1.3, enabled: true) }
        else { for i in 13...22 { actions += tap.update(tapSample(1.3, down: 0.08), time: Double(i)/10, enabled: true) } }
        actions += tap.update(tapSample(), time: failure == "long" ? 2.3 : 1.45, enabled: true)
        expect(!actions.contains(where: { if case .click = $0 { return true }; return false }), "\(failure) tap never clicks")
        expect(!tap.clickPending, "\(failure) tap clears pending input")
    }
    let handMove = readyTap()
    expect(handMove.update(tapSample(palmY: 0.74), time: 1.2, enabled: true).contains(where: { if case .move = $0 { return true }; return false }), "moving the whole hand still moves the pointer")
    expect(!handMove.tapPending, "whole-hand movement is not a tap")
    let noAim = armed(.indexTap)
    _ = noAim.update(tapSample(1.3, down: 0.08), time: 0.9, enabled: true)
    expect(!noAim.tapPending, "tap cannot start without a settled aiming history")
    let changedMode = readyTap()
    _ = changedMode.update(tapSample(1.62, down: 0.02), time: 1.2, enabled: true)
    changedMode.clickGesture = .pinch
    expect(!changedMode.clickPending && !changedMode.armed, "changing click mode cancels pending input and requires restart")

    let relative = armed(.indexTap)
    _ = relative.update(tapSample(palmX: 0.7), time: 0.9, enabled: true)
    expect(relative.update(tapSample(palmX: 0.7), time: 1.1, enabled: true) == [.move(HandPoint(x: 0.5, y: 0.5))], "off-center starting hand maps to screen center")
    for i in 0...15 { _ = relative.update(tapSample(palmX: 0.54), time: 1.15 + Double(i)*0.02, enabled: true) }
    expect(relative.feedbackPoint!.x < 0.001, "quick 16 percent camera-width palm travel reaches the left edge")
    for i in 0...18 { _ = relative.update(tapSample(palmX: 0.86), time: 1.5 + Double(i)*0.02, enabled: true) }
    expect(relative.feedbackPoint!.x > 0.999, "quick 32 percent camera-width travel spans the screen")
    let beforeCurl = relative.feedbackPoint!
    var sideFinger = tapSample(palmX: 0.86)
    sideFinger.pointer.x = 0.8
    _ = relative.update(sideFinger, time: 1.9, enabled: true)
    expect(abs(relative.feedbackPoint!.x - beforeCurl.x) < 0.001 && !relative.clickPending, "finger-only lateral motion does not pull the cursor or click")
    let beforeLoss = relative.feedbackPoint!
    _ = relative.update(nil, time: 1.95, enabled: true)
    _ = relative.update(tapSample(palmX: 0.78), time: 2.05, enabled: true)
    _ = relative.update(tapSample(palmX: 0.78), time: 2.2, enabled: true)
    expect(relative.feedbackPoint!.distance(to: beforeLoss) < 0.001, "brief reacquisition reanchors without a pointer jump")
    relative.pauseTracking(); relative.pauseTracking()
    _ = relative.update(tapSample(palmX: 0.3), time: 3.0, enabled: true)
    _ = relative.update(tapSample(palmX: 0.3), time: 3.25, enabled: true)
    _ = relative.update(tapSample(palmX: 0.3), time: 3.4, enabled: true)
    expect(relative.feedbackPoint!.distance(to: beforeLoss) < 0.001, "long reacquisition preserves cursor and reanchors a newly positioned palm")
    relative.recenterPointer()
    expect(relative.armed && !relative.clickPending, "recenter retains activation and cancels actions")
    expect(relative.update(tapSample(palmX: 0.7), time: 3.5, enabled: true).isEmpty, "recenter requires a fresh pointer dwell")
    expect(relative.update(tapSample(palmX: 0.7), time: 3.65, enabled: true) == [.move(HandPoint(x: 0.5, y: 0.5))], "recenter uses the next comfortable pointing position")
    let modestTap = readyTap()
    let modestTarget = modestTap.feedbackPoint!
    _ = modestTap.update(tapSample(1.62, down: 0.02, palmX: 0.51), time: 1.2, enabled: true)
    _ = modestTap.update(tapSample(1.5, down: 0.036, palmX: 0.52), time: 1.3, enabled: true)
    expect(modestTap.update(tapSample(1.60, down: 0.018, palmX: 0.52), time: 1.4, enabled: true) == [.click(modestTarget)], "modest bend and partial upward return click despite slight palm drift")
    _ = modestTap.update(tapSample(palmX: 0.52), time: 1.5, enabled: true)
    expect(modestTap.feedbackPoint == modestTarget, "cursor remains on target after a tap with small palm drift")
    let finishingAim = readyTap()
    _ = finishingAim.update(tapSample(palmX: 0.52), time: 1.18, enabled: true)
    let displayedTarget = finishingAim.feedbackPoint!
    expect(displayedTarget.x > 0.5, "small final aiming adjustment moves the displayed cursor")
    expect(finishingAim.update(tapSample(1.5, down: 0.04, palmX: 0.52), time: 1.22, enabled: true) == [.move(displayedTarget)], "tap locks the displayed target rather than jumping to an older aiming frame")
    let jitter = readyTap()
    var jitterActions: [MacGestureAction] = []
    for i in 0...20 {
        jitterActions += jitter.update(tapSample(i % 2 == 0 ? 1.65 : 1.7, down: i % 2 == 0 ? 0.01 : 0), time: 1.2 + Double(i)*0.03, enabled: true)
    }
    expect(!jitterActions.contains(where: { if case .click = $0 { return true }; return false }), "small repeated finger jitter never clicks")
    let noReturn = readyTap()
    _ = noReturn.update(tapSample(1.5, down: 0.04), time: 1.2, enabled: true)
    var heldActions: [MacGestureAction] = []
    for i in 13...24 { heldActions += noReturn.update(tapSample(1.5, down: 0.04), time: Double(i)/10, enabled: true) }
    expect(!heldActions.contains(where: { if case .click = $0 { return true }; return false }), "holding a bent finger without upward return never clicks")
    let recenteredTap = readyTap()
    _ = recenteredTap.update(tapSample(1.5, down: 0.04), time: 1.2, enabled: true)
    recenteredTap.recenterPointer()
    expect(!recenteredTap.clickPending && recenteredTap.update(tapSample(), time: 1.3, enabled: true).isEmpty, "recenter cancels pending tap without an input event")
    let sensitivity = readyTap()
    _ = sensitivity.update(tapSample(1.5, down: 0.04), time: 1.2, enabled: true)
    sensitivity.pointerGain = 6
    expect(!sensitivity.armed && !sensitivity.clickPending, "changing sensitivity clears activation and pending actions")
    let steady = readyTap()
    var steadyActions: [MacGestureAction] = []
    for i in 0...60 {
        let offset = i % 2 == 0 ? 0.0025 : -0.0025
        steadyActions += steady.update(tapSample(palmX: 0.5 + offset, palmY: 0.7 - offset), time: 1.2 + Double(i)*0.065, enabled: true)
    }
    expect(steady.feedbackPoint == HandPoint(x: 0.5, y: 0.5), "small sustained palm jitter holds the cursor exactly still")
    expect(!steadyActions.contains(where: { if case .click = $0 { return true }; return false }), "palm jitter cannot become a click")
    func correction(steps: Int) -> Double {
        let engine = readyTap()
        for i in 1...steps { _ = engine.update(tapSample(palmX: 0.5 + 0.04 * Double(i)/Double(steps)), time: 1.15 + Double(i)*0.065, enabled: true) }
        for i in 1...12 { _ = engine.update(tapSample(palmX: 0.54), time: 1.15 + Double(steps+i)*0.065, enabled: true) }
        return engine.feedbackPoint!.x - 0.5
    }
    let slow = correction(steps: 30), fast = correction(steps: 2)
    expect(slow > 0.02 && slow < 0.05, "small deliberate correction remains possible at low gain")
    expect(fast > slow * 1.8, "quick movement gets more travel than the same slow correction")
    let afterPause = readyTap()
    _ = afterPause.update(tapSample(palmX: 0.6), time: 1.2, enabled: true)
    let pausedPosition = afterPause.feedbackPoint!
    afterPause.pauseTracking()
    _ = afterPause.update(tapSample(palmX: 0.25), time: 1.3, enabled: true)
    _ = afterPause.update(tapSample(palmX: 0.25), time: 1.55, enabled: true)
    _ = afterPause.update(tapSample(palmX: 0.25), time: 1.7, enabled: true)
    expect(afterPause.feedbackPoint == pausedPosition, "tracking pause clears filter velocity and pending smoothing")
    print("PASS: \(checks) native gesture assertions; no OS events emitted")
    return 0
}
