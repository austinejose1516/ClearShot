import SwiftUI

/// Dark veil over everything except `hole` (even-odd fill makes the cut-out).
struct DimLayer: View {
    /// What the veil is made of: one place to change.
    static let veil = Color.black.opacity(0.28)

    let size: CGSize
    let hole: CGRect?

    var body: some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            if let hole { path.addRect(hole) }
        }
        .fill(Self.veil, style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }
}

/// A line of text in a small glass capsule: a box's size, the pointer's place, the hint under the menu bar.
struct GlassTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .capsule)
            .fixedSize()
            .allowsHitTesting(false)
    }
}

extension GlassTag {
    /// About how big a tag is, for placing it clear of the screen's edge before it is laid out.
    static let roughSize = CGSize(width: 96, height: 24)
}
