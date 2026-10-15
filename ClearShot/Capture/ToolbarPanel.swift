import AppKit
import ClearShotCore
import SwiftUI

/// The glass bar at the bottom centre of the screen before (and, for a scrolling capture, during) a recording
/// or a scrolling capture. A non-activating panel that still becomes key, so Enter and Esc work without pulling
/// the user's app to the back (like the capture overlay).
final class ToolbarPanel: NSPanel {
    /// The space between the bar and the bottom of the visible screen (above the Dock).
    static let bottomGap: CGFloat = 16

    var onReturn: (() -> Void)?
    var onEscape: (() -> Void)?

    init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        alphaValue = 0
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: onReturn?()   // Return, keypad Enter
        case 53: onEscape?()        // Esc
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    /// Makes the window exist for the window server (so a capture can leave it out) without showing anything.
    func reserve() {
        orderFrontRegardless()
    }

    func show<Content: View>(_ content: Content, on screen: NSScreen) {
        let view = FirstMouseHostingView(rootView: content)
        view.sizingOptions = .intrinsicContentSize   // the panel takes SwiftUI's ideal size, so nothing is clipped
        contentView = view
        view.layoutSubtreeIfNeeded()
        setFrame(Self.bottomCentre(size: view.intrinsicContentSize, on: screen), display: true)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        animator().alphaValue = 1
    }

    /// Centred, just above the bottom of the visible screen.
    static func bottomCentre(size: CGSize, on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        return CGRect(x: visible.midX - size.width / 2, y: visible.minY + bottomGap, width: size.width, height: size.height)
    }
}

// MARK: - The toolbar's parts

/// The glass capsule every toolbar and bar sits in.
struct ToolbarCapsule<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 6) { content }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .padding(12)   // room for the glass shadow
            .fixedSize()
    }
}

struct ToolbarCloseButton: View {
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ToolbarSeparator: View {
    var body: some View {
        Divider().frame(height: 20).padding(.horizontal, 2)
    }
}

/// One switch in a toolbar: an icon and a word. On, it is bright on an accent-coloured capsule; off, it is
/// faded with no capsule. The difference must hold for a grey accent (Graphite) too.
struct OptionChip: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 16)
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background {
                if isOn {
                    Capsule().fill(.tint.opacity(0.22))
                        .overlay(Capsule().strokeBorder(.tint.opacity(0.45), lineWidth: 1))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
        .animation(.snappy(duration: 0.2), value: isOn)
    }
}

/// "Change Area" / "Change Window": pick again.
struct ToolbarChangeButton: View {
    let title: String
    let action: () -> Void

    /// None for a whole screen: there is nothing to pick.
    static func title(for kind: CaptureKind) -> String? {
        switch kind {
        case .fullScreen: nil
        case .window: "Change Window"
        case .area, .scrolling: "Change Area"
        }
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: title == "Change Window" ? "macwindow" : "rectangle.dashed")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 8)
                .frame(height: 28)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Pick again")
    }
}

/// The main button at the right end of a toolbar (Record, Start, Done, Stop): white on a filled capsule.
struct ToolbarActionButton<Label: View>: View {
    let fill: AnyShapeStyle
    let help: String
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { label }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minWidth: 84, minHeight: 28)
                .background(fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
