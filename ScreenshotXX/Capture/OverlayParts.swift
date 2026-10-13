import SwiftUI

/// Dark veil over everything except `hole` (even-odd fill makes the cut-out).
struct DimLayer: View {
    let size: CGSize
    let hole: CGRect?

    var body: some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            if let hole { path.addRect(hole) }
        }
        .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }
}
