import AppKit
import AVFoundation

/// Display-only landmarks can be partial. Input still requires the stricter
/// recognition sample; a visible skeleton does not mean control is armed.
struct TrackingFrame {
    var sample: HandSample?
    var points: [HandJoint: HandPoint]
    var aspect: Double
    var hint: String
    var allowRecovery: Bool = true
    var clickIndicator = false
}

final class TrackingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class CameraPreview: NSView {
    let videoLayer = AVCaptureVideoPreviewLayer()
    let bones = CAShapeLayer(), joints = CAShapeLayer(), pointer = CAShapeLayer(), pinchLine = CAShapeLayer()
    private var lastFrame: TrackingFrame?
    private static let chains: [[HandJoint]] = [
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.indexMCP, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.middleMCP, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.ringMCP, .littleMCP, .littlePIP, .littleDIP, .littleTip],
        [.littleMCP, .wrist],
    ]
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 14; layer?.masksToBounds = true
        videoLayer.videoGravity = .resizeAspect; videoLayer.isHidden = true
        layer?.addSublayer(videoLayer)
        for shape in [bones, joints, pinchLine, pointer] { layer?.addSublayer(shape) }
        bones.fillColor = nil; bones.strokeColor = NSColor.systemMint.cgColor; bones.lineWidth = 2
        joints.fillColor = NSColor.systemMint.cgColor; joints.strokeColor = NSColor.black.withAlphaComponent(0.4).cgColor; joints.lineWidth = 1
        pinchLine.fillColor = nil; pinchLine.lineWidth = 3
        pointer.strokeColor = NSColor.white.cgColor; pointer.lineWidth = 2.5
        pointer.shadowColor = NSColor.black.cgColor; pointer.shadowOpacity = 0.55; pointer.shadowRadius = 5
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func layout() { super.layout(); videoLayer.frame = bounds; drawLandmarks() }
    func connect(_ session: AVCaptureSession) {
        videoLayer.session = session; videoLayer.isHidden = false; mirror()
    }
    private func mirror() {
        if let connection = videoLayer.connection, connection.isVideoMirroringSupported, !connection.isVideoMirrored {
            connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = true
        }
    }
    func clear() {
        clearTracking(); videoLayer.isHidden = true
    }
    func clearTracking() {
        lastFrame = nil
        for shape in [bones, joints, pinchLine, pointer] { shape.path = nil }
    }
    func show(_ frame: TrackingFrame) { lastFrame = frame; mirror(); drawLandmarks() }
    private func drawLandmarks() {
        guard let frame = lastFrame else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let aspect = CGFloat(max(0.1, frame.aspect))
        let width = min(bounds.width, bounds.height * aspect), height = width / aspect
        func point(_ p: HandPoint) -> CGPoint {
            CGPoint(x: (bounds.width - width) / 2 + p.x * width,
                    y: (bounds.height - height) / 2 + (1 - p.y) * height)
        }
        let bonePath = CGMutablePath(), jointPath = CGMutablePath()
        for chain in Self.chains {
            for (a, b) in zip(chain, chain.dropFirst()) {
                if let p = frame.points[a], let q = frame.points[b] {
                    bonePath.move(to: point(p)); bonePath.addLine(to: point(q))
                }
            }
        }
        for value in frame.points.values {
            let p = point(value); jointPath.addEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
        }
        bones.path = bonePath; joints.path = jointPath
        let closed = frame.clickIndicator
        let color = closed ? NSColor.systemOrange : NSColor.systemMint
        pointer.fillColor = color.cgColor; pinchLine.strokeColor = color.cgColor
        if let index = frame.points[.indexTip] {
            let p = point(index), radius: CGFloat = closed ? 13 : 9
            pointer.path = CGPath(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2), transform: nil)
            if let thumb = frame.points[.thumbTip] {
                let path = CGMutablePath(); path.move(to: p); path.addLine(to: point(thumb)); pinchLine.path = path
            } else { pinchLine.path = nil }
        } else { pointer.path = nil; pinchLine.path = nil }
    }
}

/// A click-through dot follows the pointer without taking focus or intercepting
/// events. It is visible only while real control has a valid pointing target.
final class CursorFeedback {
    let panel: TrackingPanel
    let dot = CAShapeLayer()
    init() {
        panel = TrackingPanel(contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .statusBar; panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView!.wantsLayer = true; panel.contentView!.layer?.addSublayer(dot)
        dot.path = CGPath(ellipseIn: CGRect(x: 6, y: 6, width: 24, height: 24), transform: nil)
        dot.lineWidth = 2; dot.strokeColor = NSColor.systemMint.cgColor
        dot.fillColor = NSColor.systemMint.withAlphaComponent(0.18).cgColor
    }
    func show(at point: HandPoint, display: CGDirectDisplayID, pinched: Bool) {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display
        }) else { hide(); return }
        let frame = screen.frame
        panel.setFrameOrigin(NSPoint(x: frame.minX + point.x * (frame.width - 1) - 18,
                                     y: frame.maxY - point.y * (frame.height - 1) - 18))
        let color = pinched ? NSColor.systemOrange : NSColor.systemMint
        CATransaction.begin(); CATransaction.setDisableActions(true)
        dot.strokeColor = color.cgColor; dot.fillColor = color.withAlphaComponent(pinched ? 0.55 : 0.18).cgColor
        CATransaction.commit(); panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
}
