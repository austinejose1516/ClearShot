import AppKit
import ClearShotCore
import QuartzCore

/// The card becomes the editor and the editor becomes the card again, as one picture that flies between them.
/// Edit: the card leaves the row and its picture flies to where the editor shows it; the editor fades in
/// around it. Done or close: the editor fades out, its picture flies into the card's thumbnail, and the card
/// comes back. The picture is a Core Animation layer on a see-through panel, so it moves on the GPU with a
/// spring. Without a card (closed meanwhile) the editor just fades in and out.
@MainActor
enum CardTransition {
    /// Set once at launch.
    static weak var cards: QuickAccessController?

    private static let fade: TimeInterval = 0.18

    /// How long the picture lifts off the card before it flies.
    private static let lift: TimeInterval = 0.15
    /// How long Stage Manager takes to move another app into its strip. The picture rests meanwhile: anything
    /// that moves during that swap stutters, because macOS is busy redrawing the screen.
    private static let stageSwap: Duration = .milliseconds(450)

    /// `landing` says where the editor shows the picture on screen.
    static func open(_ window: NSWindow, for id: Capture.ID, landing: @escaping () -> CGRect?) {
        guard let card = cards?.sendAway(id) else { return WindowPresenter.show(window) }
        let started = ContinuousClock.now
        let flight = Flight(image: card.image, from: card.thumbnail)
        // ClearShot becomes the active app now, while the Edit click is the current event: activation asked for
        // later is refused, and Stage Manager then leaves the editor in its strip. The editor window itself comes
        // once the picture has landed, so Stage Manager's swap does not run during the flight.
        let swapsStage = Self.stageManagerIsOn && Self.frontAppHasWindows()
        WindowPresenter.becomeRegularApp()
        flight.lift(duration: lift) {
            guard let target = landing() else {
                WindowPresenter.show(window)
                flight.fadeOut(duration: fade)
                return
            }
            flight.move(to: target) {
                window.alphaValue = 0
                WindowPresenter.show(window)
                Task {
                    if swapsStage { try? await Task.sleep(for: stageSwap) }
                    DiagnosticLog.write("edit open: landed, stage swap \(swapsStage ? "waited for" : "not needed"), "
                                        + "editor in after \(ms(ContinuousClock.now - started)); app active=\(NSApp.isActive)")
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = fade
                        window.animator().alphaValue = 1
                    }, completionHandler: nil)
                    flight.fadeOut(duration: fade)
                }
            }
        }
    }

    private static var stageManagerIsOn: Bool {
        UserDefaults(suiteName: "com.apple.WindowManager")?.bool(forKey: "GloballyEnabled") == true
    }

    /// Whether the app in front has windows on screen (the desktop does not count): only then does Stage Manager
    /// have something to move away.
    private static func frontAppHasWindows() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication, front != .current,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        return windows.contains {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == front.processIdentifier && ($0[kCGWindowLayer as String] as? Int) == 0
        }
    }

    /// `picture` is what the card shows from now on (nil: what it showed before); `source` is where the editor
    /// shows it. `done` runs as the picture lands: close the window and update the card, which then shows.
    static func close(_ window: NSWindow, for id: Capture.ID, picture: CGImage?, from source: CGRect?,
                      then done: @escaping @MainActor () -> Void) {
        let image = picture ?? cards?.picture(of: id)
        let thumbnail = image.flatMap { cards?.makeRoom(for: id, imageSize: CGSize(width: $0.width, height: $0.height)) }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fade
            window.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                window.orderOut(nil)
                window.alphaValue = 1
            }
        })
        guard let image, let thumbnail, let source else {
            Task {
                try? await Task.sleep(for: .seconds(fade))
                done()
                cards?.bringBack(id)
            }
            return
        }
        let flight = Flight(image: image, from: source)
        flight.move(to: thumbnail) {
            done()
            cards?.bringBack(id)
            flight.fadeOut(duration: 0.12)
        }
    }
}

/// One picture flying across the screen, on a see-through panel over every screen. A soft shadow follows it
/// with the same spring; it is drawn from a rounded-rectangle path (no fill), so see-through parts of the
/// picture (a window's corners) stay see-through.
@MainActor
private final class Flight {
    private static let cornerRadius: CGFloat = 9

    private let panel: NSPanel
    private let shadow = CALayer()
    private let picture = CALayer()

    init(image: CGImage, from start: CGRect) {
        let area = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        panel = NSPanel(contentRect: area, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let view = NSView(frame: CGRect(origin: .zero, size: area.size))
        view.wantsLayer = true
        panel.contentView = view

        shadow.shadowColor = NSColor.black.cgColor
        shadow.shadowOpacity = 0.3
        shadow.shadowRadius = 14
        shadow.shadowOffset = CGSize(width: 0, height: -4)
        picture.contents = image
        picture.contentsGravity = .resize
        picture.cornerRadius = Self.cornerRadius
        picture.masksToBounds = true
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        for layer in [shadow, picture] {
            layer.contentsScale = scale
            layer.frame = local(start)
            view.layer?.addSublayer(layer)
        }
        shadow.shadowPath = Self.outline(start.size)
        panel.orderFrontRegardless()
    }

    private static func outline(_ size: CGSize) -> CGPath {
        CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    }

    /// Screen coordinates to the panel's.
    private func local(_ rect: CGRect) -> CGRect {
        rect.offsetBy(dx: -panel.frame.minX, dy: -panel.frame.minY)
    }

    /// The picture grows a little and its shadow deepens, as if picked up off the card.
    func lift(duration: TimeInterval, then done: @escaping @MainActor () -> Void) {
        let from = picture.frame
        let lifted = from.insetBy(dx: -from.width * 0.05, dy: -from.height * 0.05)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { done() } }
        func ease(_ key: String, _ start: Any, _ finish: Any) -> CABasicAnimation {
            let animation = CABasicAnimation(keyPath: key)
            animation.fromValue = start
            animation.toValue = finish
            return animation
        }
        for layer in [shadow, picture] {
            layer.add(ease("bounds", NSValue(rect: CGRect(origin: .zero, size: from.size)), NSValue(rect: CGRect(origin: .zero, size: lifted.size))), forKey: "bounds")
            layer.frame = lifted
        }
        shadow.add(ease("shadowPath", Self.outline(from.size), Self.outline(lifted.size)), forKey: "shadowPath")
        shadow.add(ease("shadowRadius", 14, 24), forKey: "shadowRadius")
        shadow.add(ease("shadowOpacity", 0.3, 0.42), forKey: "shadowOpacity")
        shadow.shadowPath = Self.outline(lifted.size)
        shadow.shadowRadius = 24
        shadow.shadowOpacity = 0.42
        CATransaction.commit()
    }

    func move(to target: CGRect, then done: @escaping @MainActor () -> Void) {
        let end = local(target)
        let from = (picture.presentation() ?? picture).frame
        guard from != end else { return done() }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { done() } }
        func spring(_ key: String, _ start: Any, _ finish: Any) -> CASpringAnimation {
            let spring = CASpringAnimation(keyPath: key)
            spring.fromValue = start
            spring.toValue = finish
            spring.mass = 1
            spring.stiffness = 220
            spring.damping = 28   // no bounce: it settles, it does not wobble
            spring.duration = spring.settlingDuration
            return spring
        }
        for layer in [shadow, picture] {
            layer.add(spring("position", NSValue(point: CGPoint(x: from.midX, y: from.midY)), NSValue(point: CGPoint(x: end.midX, y: end.midY))), forKey: "position")
            layer.add(spring("bounds", NSValue(rect: CGRect(origin: .zero, size: from.size)), NSValue(rect: CGRect(origin: .zero, size: end.size))), forKey: "bounds")
            layer.frame = end
        }
        shadow.add(spring("shadowPath", Self.outline(from.size), Self.outline(end.size)), forKey: "shadowPath")
        shadow.shadowPath = Self.outline(end.size)
        CATransaction.commit()
    }

    /// Fades the picture away and takes the panel down.
    func fadeOut(duration: TimeInterval) {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            MainActor.assumeIsolated {
                self.panel.orderOut(nil)
                self.panel.contentView = nil
            }
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = duration
        for layer in [shadow, picture] {
            layer.add(fade, forKey: "opacity")
            layer.opacity = 0
        }
        CATransaction.commit()
    }
}

/// "123 ms", for the transition's timing log.
private func ms(_ duration: Duration) -> String {
    "\(Int(duration / .milliseconds(1))) ms"
}
