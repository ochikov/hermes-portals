import AppKit
import AVFoundation
import ApplicationServices
import Vision

if CommandLine.arguments.contains("--self-test") { exit(runEngineTests()) }

final class CameraFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "portals.camera", qos: .userInitiated)
    let request = VNDetectHumanHandPoseRequest()
    var onFrame: ((TrackingFrame, Double, Int) -> Void)?
    var onError: ((String, Int) -> Void)?
    private var generation = 0
    private var previousFrame = 0.0
    private let mapping: [HandJoint: VNHumanHandPoseObservation.JointName] = [
        .wrist: .wrist, .thumbCMC: .thumbCMC, .thumbMP: .thumbMP, .thumbIP: .thumbIP, .thumbTip: .thumbTip,
        .indexMCP: .indexMCP, .indexPIP: .indexPIP, .indexDIP: .indexDIP, .indexTip: .indexTip,
        .middleMCP: .middleMCP, .middlePIP: .middlePIP, .middleDIP: .middleDIP, .middleTip: .middleTip,
        .ringMCP: .ringMCP, .ringPIP: .ringPIP, .ringDIP: .ringDIP, .ringTip: .ringTip,
        .littleMCP: .littleMCP, .littlePIP: .littlePIP, .littleDIP: .littleDIP, .littleTip: .littleTip,
    ]
    override init() { super.init(); request.maximumHandCount = 2 }
    func start(generation: Int) {
        queue.async {
            self.generation = generation
            do {
                if self.session.inputs.isEmpty {
                    guard let device = AVCaptureDevice.default(for: .video) else {
                        throw NSError(domain: "Portals", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera available"])
                    }
                    let input = try AVCaptureDeviceInput(device: device)
                    let output = AVCaptureVideoDataOutput()
                    output.alwaysDiscardsLateVideoFrames = true
                    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    output.setSampleBufferDelegate(self, queue: self.queue)
                    self.session.beginConfiguration()
                    if self.session.canSetSessionPreset(.vga640x480) { self.session.sessionPreset = .vga640x480 }
                    guard self.session.canAddInput(input), self.session.canAddOutput(output) else {
                        self.session.commitConfiguration()
                        throw NSError(domain: "Portals", code: 2, userInfo: [NSLocalizedDescriptionKey: "Camera could not be configured"])
                    }
                    self.session.addInput(input); self.session.addOutput(output)
                    self.session.commitConfiguration()
                }
                self.previousFrame = 0
                self.session.startRunning()
                if !self.session.isRunning { self.onError?("Camera did not start; check Camera permission", generation) }
            } catch { self.onError?(error.localizedDescription, generation) }
        }
    }
    func stop() { queue.async { self.session.stopRunning() } }
    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - previousFrame >= 0.065, let pixel = CMSampleBufferGetImageBuffer(buffer) else { return }
        previousFrame = now
        let aspect = Double(CVPixelBufferGetWidth(pixel)) / Double(CVPixelBufferGetHeight(pixel))
        do {
            try VNImageRequestHandler(cvPixelBuffer: pixel, orientation: .up).perform([request])
            var points: [HandJoint: HandPoint] = [:], strict: [HandJoint: HandPoint] = [:]
            let count = request.results?.count ?? 0
            if count == 1, let observation = request.results?.first {
                let recognized = try observation.recognizedPoints(.all)
                for (joint, name) in mapping {
                    if let point = recognized[name], point.confidence >= 0.25 {
                        // Mirrored top-left coordinates for both drawing and recognition.
                        let location = HandPoint(x: 1 - Double(point.location.x), y: 1 - Double(point.location.y))
                        if location.valid {
                            points[joint] = location
                            if point.confidence >= 0.55 { strict[joint] = location }
                        }
                    }
                }
            }
            let sample = HandSample.recognize(strict)
            let hint = count > 1 ? "Show only one hand" : count == 0 ? "Show your hand and wrist" :
                sample == nil ? "Show your index fingertip and wrist" :
                sample?.pose == .aim ? "Moving only · show your thumb and curl the other fingers to click" :
                "\(sample!.pose.rawValue.uppercased()) · \(points.count)/21 joints"
            onFrame?(TrackingFrame(sample: sample, points: points, aspect: aspect, hint: hint, allowRecovery: count < 2), now, generation)
        } catch {
            onFrame?(TrackingFrame(sample: nil, points: [:], aspect: aspect, hint: "Tracking unavailable · try Preview again", allowRecovery: false), now, generation)
        }
    }
}

final class MacInput {
    var display: CGDirectDisplayID = CGMainDisplayID()
    // Tagged pairs never leave a mouse button or a modifier held down.
    private let tag: Int64 = 0x48504f5254
    func apply(_ action: MacGestureAction) -> String? {
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else { return "Accessibility permission is required" }
        func position(_ p: HandPoint) -> CGPoint {
            let bounds = CGDisplayBounds(display)
            return CGPoint(x: bounds.minX + p.x * max(1, bounds.width - 1),
                           y: bounds.minY + p.y * max(1, bounds.height - 1))
        }
        func post(_ event: CGEvent?) { event?.setIntegerValueField(.eventSourceUserData, value: tag); event?.post(tap: .cghidEventTap) }
        switch action {
        case .move(let point):
            post(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: position(point), mouseButton: .left))
        case .click(let point):
            let at = position(point)
            guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: at, mouseButton: .left),
                  let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: at, mouseButton: .left) else { return "Mouse event unavailable" }
            down.setIntegerValueField(.mouseEventClickState, value: 1); up.setIntegerValueField(.mouseEventClickState, value: 1)
            post(down); post(up)
        case .scroll(let amount):
            post(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: amount, wheel2: 0, wheel3: 0))
        case .switchApp(let direction):
            // A stable alphabetical ring reaches every running regular app, instead
            // of repeated Cmd-Tab simply toggling the two most recent applications.
            let apps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }.sorted {
                let comparison = ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "")
                return comparison == .orderedSame ? $0.processIdentifier < $1.processIdentifier : comparison == .orderedAscending
            }
            guard !apps.isEmpty else { return "No other app is running" }
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let current = apps.firstIndex(where: { $0.processIdentifier == front }) ?? (direction > 0 ? -1 : 0)
            let target = apps[(current + direction + apps.count) % apps.count]
            return target.activate(options: [.activateIgnoringOtherApps]) ? "Switched to \(target.localizedName ?? "app")" : "App could not be activated"
        }
        return nil
    }
}

final class Controller: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let feed = CameraFeed(), engine = MacGestureEngine(), input = MacInput()
    var window: NSWindow!
    var menuItem: NSStatusItem!
    let preview = CameraPreview(frame: .zero)
    let cursorFeedback = CursorFeedback()
    var trackingPanel: TrackingPanel!
    let trackingState = NSTextField(wrappingLabelWithString: "Camera off")
    let trackingDetail = NSTextField(wrappingLabelWithString: "Show one hand and wrist")
    let trackingAction = NSTextField(wrappingLabelWithString: "No input sent")
    var clickFlashUntil = 0.0
    let stateLabel = NSTextField(wrappingLabelWithString: "Camera off · choose Preview or Mac control")
    let permissionLabel = NSTextField(wrappingLabelWithString: "")
    let actionLabel = NSTextField(wrappingLabelWithString: "No mouse or app actions have been sent")
    let displayPicker = NSPopUpButton()
    var languagePickers: [NSPopUpButton] = []
    var clickPickers: [NSPopUpButton] = []
    let sensitivityPicker = NSPopUpButton()
    let pointerGains = [2.0, 4.0, 6.0]
    let clickGuideLabel = NSTextField(wrappingLabelWithString: "")
    var localizedLabels: [(NSTextField, String)] = []
    var localizedButtons: [(NSButton, String)] = []
    var localizedMenuItems: [(NSMenuItem, String)] = []
    var lastDetail = "Show one hand and wrist", lastAction = "No mouse or app actions have been sent"
    var menuState = "Off"
    var displayIDs: [CGDirectDisplayID] = []
    var capturing = false, controlEnabled = false, generation = 0, starting = false
    var lastFrame = 0.0, lastStatus = "Camera off", lastStatusWrite = 0.0
    var globalKeyMonitor: Any?, localKeyMonitor: Any?, watchdog: Timer?
    var activity: NSObjectProtocol?
    let instance = UUID().uuidString
    let stateDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Hermes Portals Control", isDirectory: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stateDirectory.path)
        try? FileManager.default.removeItem(at: stateDirectory.appendingPathComponent("stop.request"))
        engine.clickGesture = ClickGesture(rawValue: UserDefaults.standard.string(forKey: "clickGesture") ?? "indexTap") ?? .indexTap
        let savedGain = UserDefaults.standard.double(forKey: "pointerGain")
        engine.pointerGain = pointerGains.contains(savedGain) ? savedGain : 4
        buildMenu(); buildWindow(); buildTrackingPanel(); refreshLanguage()
        feed.onFrame = { [weak self] frame, time, token in
            DispatchQueue.main.async { self?.received(frame, time: time, token: token) }
        }
        feed.onError = { [weak self] error, token in
            DispatchQueue.main.async {
                guard let self = self, self.generation == token else { return }
                self.stopWithMessage(error)
            }
        }
        installEscapeMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.stopWithMessage("Stopped with Escape"); return nil }
            return event
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepStop), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.heartbeat() }
        writeStatus(); showWindow()
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: PortalsLanguage.text(title), target: self, action: action)
        button.bezelStyle = .rounded
        localizedButtons.append((button, title))
        return button
    }
    private func text(_ value: String, size: CGFloat = 13, bold: Bool = false) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: PortalsLanguage.text(value))
        label.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        localizedLabels.append((label, value))
        return label
    }
    private func languagePicker() -> NSPopUpButton {
        let picker = NSPopUpButton()
        picker.addItems(withTitles: ["English", "Български"])
        picker.selectItem(at: PortalsLanguage.code == "bg" ? 1 : 0)
        picker.setAccessibilityLabel("Language / Език")
        picker.target = self; picker.action = #selector(changeLanguage(_:))
        languagePickers.append(picker)
        return picker
    }
    @objc func changeLanguage(_ sender: NSPopUpButton) {
        PortalsLanguage.code = sender.indexOfSelectedItem == 1 ? "bg" : "en"
        UserDefaults.standard.set(PortalsLanguage.code, forKey: "interfaceLanguage")
        refreshLanguage()
    }
    private func clickPicker() -> NSPopUpButton {
        let picker = NSPopUpButton()
        picker.setAccessibilityLabel("Click gesture / Жест за клик")
        picker.target = self; picker.action = #selector(changeClickGesture(_:))
        clickPickers.append(picker)
        return picker
    }
    @objc func changeClickGesture(_ sender: NSPopUpButton) {
        let gesture: ClickGesture = sender.indexOfSelectedItem == 0 ? .indexTap : .pinch
        stopWithMessage("Click gesture changed · start control again")
        engine.clickGesture = gesture
        UserDefaults.standard.set(gesture.rawValue, forKey: "clickGesture")
        refreshLanguage()
    }
    @objc func changeSensitivity(_ sender: NSPopUpButton) {
        guard pointerGains.indices.contains(sender.indexOfSelectedItem) else { return }
        stopWithMessage("Sensitivity changed · start control again")
        engine.pointerGain = pointerGains[sender.indexOfSelectedItem]
        UserDefaults.standard.set(engine.pointerGain, forKey: "pointerGain")
    }
    @objc func recenterPointer() {
        engine.recenterPointer(); cursorFeedback.hide(); clickFlashUntil = 0
        if controlEnabled { setState(engine.message) }
    }
    func setState(_ value: String) {
        lastStatus = value
        stateLabel.stringValue = PortalsLanguage.text(value)
        trackingState.stringValue = stateLabel.stringValue
    }
    func setDetail(_ value: String) { lastDetail = value; trackingDetail.stringValue = PortalsLanguage.text(value) }
    func setAction(_ value: String) {
        lastAction = value; actionLabel.stringValue = PortalsLanguage.text(value)
        trackingAction.stringValue = actionLabel.stringValue
    }
    func setMenuState(_ value: String) { menuState = value; menuItem?.button?.title = "◒ Portals · " + PortalsLanguage.text(value) }
    func refreshLanguage() {
        for (label, key) in localizedLabels { label.stringValue = PortalsLanguage.text(key) }
        for (button, key) in localizedButtons { button.title = PortalsLanguage.text(key) }
        for (item, key) in localizedMenuItems { item.title = PortalsLanguage.text(key) }
        for picker in languagePickers { picker.selectItem(at: PortalsLanguage.code == "bg" ? 1 : 0) }
        for picker in clickPickers {
            picker.removeAllItems()
            picker.addItems(withTitles: [PortalsLanguage.text("Index tap"), PortalsLanguage.text("Thumb + index pinch")])
            picker.selectItem(at: engine.clickGesture == .indexTap ? 0 : 1)
        }
        sensitivityPicker.removeAllItems()
        sensitivityPicker.addItems(withTitles: [PortalsLanguage.text("Low · larger movements"), PortalsLanguage.text("Medium · smaller movements"), PortalsLanguage.text("High · very small movements")])
        sensitivityPicker.selectItem(at: pointerGains.firstIndex(of: engine.pointerGain) ?? 1)
        clickGuideLabel.stringValue = PortalsLanguage.text(engine.clickGesture == .indexTap ? PortalsLanguage.tapGuide : PortalsLanguage.clickGuide)
        window.title = PortalsLanguage.text("Hermes Portals · Mac Control")
        trackingPanel.title = PortalsLanguage.text("Portals · Live hand")
        setState(lastStatus); setDetail(lastDetail); setAction(lastAction); setMenuState(menuState)
        refreshPermissions()
    }
    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 710),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Hermes Portals · Mac Control"
        window.isReleasedWhenClosed = false; window.delegate = self; window.center()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
        ])
        stack.addArrangedSubview(text("Your hand. Your Mac.", size: 25, bold: true))
        stack.addArrangedSubview(languagePicker())
        stack.addArrangedSubview(clickPicker())
        sensitivityPicker.setAccessibilityLabel("Pointer sensitivity / Чувствителност на курсора")
        sensitivityPicker.target = self; sensitivityPicker.action = #selector(changeSensitivity(_:))
        let sensitivity = NSStackView(views: [text("Pointer sensitivity", size: 12), sensitivityPicker])
        sensitivity.spacing = 10; stack.addArrangedSubview(sensitivity)
        stack.addArrangedSubview(text("Local camera gestures · works while other apps are in front", size: 12))
        stateLabel.font = .boldSystemFont(ofSize: 14); stateLabel.textColor = .systemMint
        stack.addArrangedSubview(stateLabel)
        stack.addArrangedSubview(text("Your live camera and hand skeleton stay visible in a floating panel on the right.", size: 12))
        stack.addArrangedSubview(button("Show live hand", #selector(showTrackingPanel)))
        let actions = NSStackView(views: [button("Start preview", #selector(startPreview)), button("Start Mac control", #selector(startControl)), button("Stop / Esc", #selector(stop))])
        actions.spacing = 8; stack.addArrangedSubview(actions)
        stack.addArrangedSubview(text(PortalsLanguage.instructions, size: 12))
        let displays = NSStackView(views: [text("Control display", size: 12), displayPicker]); displays.spacing = 10
        displayPicker.target = self; displayPicker.action = #selector(selectDisplay)
        stack.addArrangedSubview(displays); populateDisplays()
        permissionLabel.font = .systemFont(ofSize: 12); permissionLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(permissionLabel)
        let permissions = NSStackView(views: [button("Request Accessibility…", #selector(requestAccessibility)), button("Show app in Finder", #selector(revealApp))])
        permissions.spacing = 8; stack.addArrangedSubview(permissions)
        actionLabel.font = .systemFont(ofSize: 12); actionLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(actionLabel)
        stack.addArrangedSubview(text("Preview never sends Mac input. Video stays on this Mac; nothing is recorded. Closing this window keeps the menu bar controller running. Use Stop or Escape to finish.", size: 11))
        for view in stack.arrangedSubviews where view is NSTextField {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }
    func buildTrackingPanel() {
        trackingPanel = TrackingPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 660),
            styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        trackingPanel.title = "Portals · Live hand"
        trackingPanel.isReleasedWhenClosed = false; trackingPanel.delegate = self
        trackingPanel.level = .floating; trackingPanel.hidesOnDeactivate = false
        trackingPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        trackingPanel.isMovableByWindowBackground = true
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        trackingPanel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: trackingPanel.contentView!.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trackingPanel.contentView!.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: trackingPanel.contentView!.topAnchor, constant: 14),
        ])
        stack.addArrangedSubview(text("LIVE HAND / ON THIS MAC", size: 11, bold: true))
        stack.addArrangedSubview(languagePicker())
        stack.addArrangedSubview(clickPicker())
        preview.translatesAutoresizingMaskIntoConstraints = false; stack.addArrangedSubview(preview)
        preview.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        preview.heightAnchor.constraint(equalTo: preview.widthAnchor, multiplier: 0.75).isActive = true
        trackingState.font = .boldSystemFont(ofSize: 14); trackingState.textColor = .systemMint
        trackingDetail.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        trackingDetail.textColor = .secondaryLabelColor
        trackingAction.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(trackingState); stack.addArrangedSubview(trackingDetail); stack.addArrangedSubview(trackingAction)
        clickGuideLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(clickGuideLabel)
        let controls = NSStackView(views: [button("Stop / Esc", #selector(stop)), button("Recenter", #selector(recenterPointer)), button("Controls", #selector(showWindow))])
        controls.spacing = 5; stack.addArrangedSubview(controls)
        for view in stack.arrangedSubviews where view is NSTextField {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        positionTrackingPanel()
    }
    func positionTrackingPanel() {
        let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == input.display
        }) ?? NSScreen.main
        guard let bounds = screen?.visibleFrame else { return }
        trackingPanel.setFrameTopLeftPoint(NSPoint(x: bounds.maxX - trackingPanel.frame.width - 16, y: bounds.maxY - 20))
    }
    @objc func showTrackingPanel() { trackingPanel.orderFrontRegardless() }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === trackingPanel { stopWithMessage("Live hand closed · camera and control stopped") }
        return true
    }
    func buildMenu() {
        menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuItem.button?.title = "◒ Portals · Off"
        let menu = NSMenu()
        for (title, selector) in [("Show controller", #selector(showWindow)), ("Show live hand", #selector(showTrackingPanel)), ("Start preview", #selector(startPreview)),
                                  ("Start Mac control", #selector(startControl)), ("Stop — Escape", #selector(stop)), ("Quit", #selector(quit))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self; menu.addItem(item)
            localizedMenuItems.append((item, title))
        }
        menuItem.menu = menu
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    @objc func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    @objc func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        setState("Allow this app in Privacy & Security → Accessibility, then press Start Mac control.")
        refreshPermissions()
    }
    func refreshPermissions() {
        let camera = AVCaptureDevice.authorizationStatus(for: .video)
        let cameraText = camera == .authorized ? "allowed" : camera == .notDetermined ? "not requested" : "not allowed"
        permissionLabel.stringValue = "\(PortalsLanguage.text("Camera")): \(PortalsLanguage.text(cameraText))  ·  Accessibility: \(PortalsLanguage.text(AXIsProcessTrusted() && CGPreflightPostEventAccess() ? "allowed" : "not allowed"))"
    }
    @objc func startPreview() { begin(control: false) }
    func installEscapeMonitor() {
        if let previous = globalKeyMonitor { NSEvent.removeMonitor(previous) }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.stopWithMessage("Stopped with Escape") }
        }
    }
    @objc func startControl() {
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
            stopWithMessage("Mac control needs Accessibility permission. Use Request Accessibility below.")
            showWindow(); return
        }
        installEscapeMonitor()
        guard globalKeyMonitor != nil else {
            stopWithMessage("Escape monitoring is unavailable. Reopen the app after allowing Accessibility."); return
        }
        begin(control: true)
    }
    func begin(control: Bool) {
        if starting { return }
        stopWithMessage("Starting camera…")
        generation += 1; let token = generation; starting = true
        writeStatus()
        let authorized = AVCaptureDevice.authorizationStatus(for: .video)
        if authorized == .authorized { startCamera(control: control, token: token) }
        else if authorized == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self, self.generation == token else { return }
                    if granted { self.startCamera(control: control, token: token) }
                    else { self.stopWithMessage("Camera access was declined. Allow it in System Settings to use gestures.") }
                }
            }
        } else { stopWithMessage("Camera access is not allowed. Enable it in Privacy & Security → Camera.") }
    }
    func startCamera(control: Bool, token: Int) {
        guard token == generation else { return }
        if control && (!AXIsProcessTrusted() || !CGPreflightPostEventAccess()) {
            stopWithMessage("Accessibility permission is no longer available"); return
        }
        engine.reset(); starting = false; capturing = true; controlEnabled = control; lastFrame = ProcessInfo.processInfo.systemUptime
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Local hand gesture tracking")
        setState(control ? "Hold an open palm still to take control" : "Preview only · no Mac input")
        setMenuState(control ? "Waiting" : "Preview")
        feed.start(generation: token)
        preview.connect(feed.session)
        setAction("No input sent in this session"); clickFlashUntil = 0
        showTrackingPanel(); window.orderOut(nil)
        refreshPermissions(); writeStatus()
    }
    func received(_ frame: TrackingFrame, time: Double, token: Int) {
        guard capturing, token == generation else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - time < 0.3 else {
            engine.pauseTracking(); cursorFeedback.hide(); preview.clearTracking(); setState("Tracking delayed · control paused")
            return
        }
        let sample = frame.sample
        lastFrame = time
        if engine.clickGesture == .indexTap && sample?.pose == .aim {
            setDetail(sample?.tapEligible == true ? "Index tap ready · thumb not needed" : "Show your index and curled middle finger")
        } else { setDetail(frame.hint) }
        if controlEnabled && (!AXIsProcessTrusted() || !CGPreflightPostEventAccess()) {
            stopWithMessage("Accessibility permission was removed · control stopped"); return
        }
        let actions = engine.update(sample, time: time, enabled: controlEnabled, allowRecovery: frame.allowRecovery)
        var displayFrame = frame
        displayFrame.clickIndicator = controlEnabled ? (engine.clickPending || now < clickFlashUntil) :
            (engine.clickGesture == .pinch ? sample?.pose == .pinch : (sample?.tapEligible == true && (sample?.indexExtension ?? 2) < 1.15))
        preview.show(displayFrame)
        setState(controlEnabled ? engine.message : "Preview · \(sample?.pose.rawValue ?? "no clear hand") · no Mac input")
        trackingState.textColor = engine.clickPending ? .systemOrange : .systemMint
        if controlEnabled && engine.armed, let point = engine.feedbackPoint,
           sample?.pose == .point || sample?.pose == .aim || engine.clickPending {
            cursorFeedback.show(at: point, display: input.display, pinched: engine.clickPending || now < clickFlashUntil)
        } else { cursorFeedback.hide() }
        setMenuState(controlEnabled ? (engine.armed ? "Control" : "Waiting") : "Preview")
        guard controlEnabled, engine.armed else { return }
        for action in actions {
            if let message = input.apply(action) { setAction(message) }
            else {
                switch action {
                case .click: setAction("Single click sent"); clickFlashUntil = now + 0.25
                case .scroll: setAction("Scrolling")
                default: break
                }
            }
        }
    }
    @objc func stop() { stopWithMessage("Stopped · camera and Mac input are off") }
    func stopWithMessage(_ message: String) {
        generation += 1; starting = false; capturing = false; controlEnabled = false; engine.reset()
        if let current = activity { ProcessInfo.processInfo.endActivity(current); activity = nil }
        feed.stop(); preview.clear(); cursorFeedback.hide()
        setState(message); setDetail("Camera off · preview cleared"); setMenuState("Off")
        trackingState.textColor = .systemMint
        refreshPermissions(); writeStatus()
    }
    @objc func sleepStop() { stopWithMessage("Stopped for sleep or session change") }
    @objc func screenChanged() { stopWithMessage("Display layout changed · choose a display and start again"); populateDisplays(); positionTrackingPanel() }
    func populateDisplays() {
        displayPicker.removeAllItems(); displayIDs = []
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                displayIDs.append(number.uint32Value); displayPicker.addItem(withTitle: screen.localizedName)
            }
        }
        if let selected = displayIDs.firstIndex(of: input.display) { displayPicker.selectItem(at: selected) }
        else if let first = displayIDs.first { input.display = first }
    }
    @objc func selectDisplay() {
        stopWithMessage("Display selected · start again to take control")
        if displayIDs.indices.contains(displayPicker.indexOfSelectedItem) { input.display = displayIDs[displayPicker.indexOfSelectedItem] }
        positionTrackingPanel()
    }
    func heartbeat() {
        let stopFile = stateDirectory.appendingPathComponent("stop.request")
        if FileManager.default.fileExists(atPath: stopFile.path) {
            try? FileManager.default.removeItem(at: stopFile)
            stopWithMessage("Stopped from Portals")
        }
        if capturing && ProcessInfo.processInfo.systemUptime - lastFrame > 0.8 {
            engine.pauseTracking(); cursorFeedback.hide(); preview.clearTracking(); setState("Waiting for camera frames · Mac input paused")
            setMenuState("Waiting")
        }
        if capturing && AVCaptureDevice.authorizationStatus(for: .video) != .authorized { stopWithMessage("Camera permission was removed") }
        if capturing && controlEnabled && !AXIsProcessTrusted() { stopWithMessage("Accessibility permission was removed") }
        if Date().timeIntervalSince1970 - lastStatusWrite > 0.9 { refreshPermissions(); writeStatus() }
    }
    func writeStatus() {
        let camera = AVCaptureDevice.authorizationStatus(for: .video)
        let status: [String: Any] = ["version": "0.3.0", "instance": instance,
            "pid": ProcessInfo.processInfo.processIdentifier, "updated_at": Date().timeIntervalSince1970,
            "capturing": capturing, "starting": starting, "control_enabled": controlEnabled, "armed": engine.armed,
            "camera_allowed": camera == .authorized, "accessibility_allowed": AXIsProcessTrusted() && CGPreflightPostEventAccess(),
            "mode": controlEnabled ? "control" : capturing ? "preview" : "off", "click_gesture": engine.clickGesture.rawValue]
        let path = stateDirectory.appendingPathComponent("status.json")
        if let data = try? JSONSerialization.data(withJSONObject: status, options: [.sortedKeys]) {
            try? data.write(to: path, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        }
        lastStatusWrite = Date().timeIntervalSince1970
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        watchdog?.invalidate(); stopWithMessage("Quit")
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
        try? FileManager.default.removeItem(at: stateDirectory.appendingPathComponent("status.json"))
    }
}

let application = NSApplication.shared
let controller = Controller()
application.setActivationPolicy(.accessory)
application.delegate = controller
application.run()
