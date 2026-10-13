import AppKit
import ScreenshotXXCore
import SwiftUI

/// Owns the Quick Access cards: one panel per capture, newest on the left, per screen.
@MainActor
final class QuickAccessController {
    private struct Entry {
        let id: Capture.ID
        let panel: QuickAccessPanel
        let displayID: CGDirectDisplayID?
    }

    private let settings: AppSettings
    private var entries: [Entry] = []          // newest first
    private var hovered: Set<Capture.ID> = []
    private var autoCloseTasks: [Capture.ID: Task<Void, Never>] = [:]
    private var screenObserver: NSObjectProtocol?

    var onEdit: ((Capture) -> Void)?
    var onDelete: ((Capture) -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout(animated: false) }
        }
    }

    func show(_ capture: Capture, on screen: NSScreen?) {
        let panel = QuickAccessPanel(frame: CGRect(origin: .zero, size: QuickAccessLayout.cardSize))
        let view = QuickAccessView(
            capture: capture,
            onEdit: { [weak self] in self?.onEdit?(capture) },
            onCopy: { ClipboardService.copy(capture.image) },
            onReveal: {
                if let url = capture.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            },
            onDelete: { [weak self] in
                self?.onDelete?(capture)
                self?.close(id: capture.id)
            },
            onClose: { [weak self] in self?.close(id: capture.id) },
            onHoverChange: { [weak self] inside in self?.hoverChanged(capture.id, inside: inside) })
        panel.contentView = FirstMouseHostingView(rootView: view)
        entries.insert(Entry(id: capture.id, panel: panel, displayID: (screen ?? NSScreen.main)?.displayID), at: 0)
        layout(animated: true, appearing: capture.id)
        scheduleAutoClose(capture.id)
    }

    func close(id: Capture.ID) {
        dismiss(id: id)
        layout(animated: true)
    }

    // MARK: - Layout

    private func layout(animated: Bool, appearing: Capture.ID? = nil) {
        var overflow: [Capture.ID] = []
        let groups = Dictionary(grouping: entries, by: { $0.displayID })
        for (displayID, group) in groups {
            // A card whose screen was unplugged moves to the main screen.
            let screen = NSScreen.screens.first { $0.displayID == displayID } ?? NSScreen.main
            guard let visible = screen?.visibleFrame else { continue }
            let frames = QuickAccessLayout.frames(count: group.count, in: visible)
            for (index, entry) in group.enumerated() {
                guard index < frames.count else { overflow.append(entry.id); continue }
                place(entry.panel, at: frames[index], animated: animated, appearing: entry.id == appearing)
            }
        }
        overflow.forEach(dismiss(id:))
    }

    private func place(_ panel: QuickAccessPanel, at frame: CGRect, animated: Bool, appearing: Bool) {
        if appearing {
            panel.setFrame(frame.offsetBy(dx: 0, dy: -24), display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
                panel.animator().alphaValue = 1
            }
        } else if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func dismiss(id: Capture.ID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let panel = entries.remove(at: index).panel
        autoCloseTasks.removeValue(forKey: id)?.cancel()
        hovered.remove(id)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
            panel.animator().setFrame(panel.frame.offsetBy(dx: 0, dy: -16), display: true)
        }, completionHandler: {
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                panel.contentView = nil
            }
        })
    }

    // MARK: - Auto-close

    private func hoverChanged(_ id: Capture.ID, inside: Bool) {
        if inside {
            hovered.insert(id)
            autoCloseTasks.removeValue(forKey: id)?.cancel()
        } else {
            hovered.remove(id)
            scheduleAutoClose(id)
        }
    }

    private func scheduleAutoClose(_ id: Capture.ID) {
        autoCloseTasks[id]?.cancel()
        let seconds = settings.cardAutoCloseSeconds
        guard seconds > 0 else { return }
        autoCloseTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.close(id: id)
        }
    }
}
