import SwiftUI

/// Dims the screen. The dim lifts while the mouse is over this screen, and a click picks the whole screen.
struct FullScreenPickOverlayView: View {
    let onPick: () -> Void

    @State private var hovering: Bool

    init(startsHovered: Bool, onPick: @escaping () -> Void) {
        self.onPick = onPick
        _hovering = State(initialValue: startsHovered)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                DimLayer(size: size, hole: nil)
                    .opacity(hovering ? 0 : 1)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active: hovering = true
                case .ended: hovering = false
                }
            }
            .onTapGesture { onPick() }
            .animation(.easeOut(duration: 0.15), value: hovering)
        }
        .ignoresSafeArea()
    }
}
