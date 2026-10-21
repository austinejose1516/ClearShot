// Draws the app icon and the menu bar glyph. Run from the repo root:
//   swift scripts/make-icon.swift && scripts/make-icns.sh
// Writes ClearShot/Resources/AppIcon-source.png (1024 px, the macOS rounded square with its margin and shadow)
// and MenuBarIcon.png / MenuBarIcon@2x.png (18 pt, black on clear: a template image, so it follows the menu bar).
import AppKit
import CoreGraphics

let resources = URL(fileURLWithPath: "ClearShot/Resources", isDirectory: true)
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: srgb, components: [r, g, b, a])!
}
let white = rgb(1, 1, 1)
let black = rgb(0, 0, 0)
// Ocean, the app's default accent: lighter at the top, deeper at the bottom.
let oceanTop = rgb(0.42, 0.78, 1.0)
let oceanBottom = rgb(0.03, 0.46, 0.90)

func context(_ size: CGFloat) -> CGContext {
    CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func save(_ ctx: CGContext, _ name: String) throws {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: resources.appendingPathComponent(name))
    print("wrote ClearShot/Resources/\(name)")
}

/// The rounded square every macOS icon sits on: 824 of 1024 px, with a soft shadow and a gradient.
func background(_ ctx: CGContext, size: CGFloat) -> CGRect {
    let side = size * 824 / 1024
    let rect = CGRect(x: (size - side) / 2, y: (size - side) / 2, width: side, height: side)
    let radius = side * 0.2237
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.035, color: rgb(0, 0, 0, 0.32))
    ctx.addPath(path); ctx.setFillColor(oceanBottom); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let gradient = CGGradient(colorsSpace: srgb, colors: [oceanTop, oceanBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    let glow = CGGradient(colorsSpace: srgb, colors: [rgb(1, 1, 1, 0.30), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
    let glowCenter = CGPoint(x: rect.midX, y: rect.maxY + side * 0.15)
    ctx.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: side * 0.95, options: [])
    ctx.restoreGState()
    return rect
}

/// A camera: body with a hump on top, a lens hole cut through to whatever is behind, and a ring inside the hole.
func camera(_ ctx: CGContext, center: CGPoint, width: CGFloat, color: CGColor) {
    let height = width * 0.68
    let body = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    let hump = CGRect(x: body.minX + width * 0.26, y: body.maxY - height * 0.1, width: width * 0.34, height: height * 0.3)
    let lens = CGPoint(x: center.x, y: center.y - height * 0.05)
    ctx.saveGState()
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(color)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: width * 0.11, cornerHeight: width * 0.11, transform: nil)); ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: hump, cornerWidth: width * 0.06, cornerHeight: width * 0.06, transform: nil)); ctx.fillPath()
    ctx.setBlendMode(.destinationOut)
    ctx.fillEllipse(in: CGRect(x: lens.x - width * 0.2, y: lens.y - width * 0.2, width: width * 0.4, height: width * 0.4))
    ctx.setBlendMode(.normal)
    ctx.fillEllipse(in: CGRect(x: lens.x - width * 0.11, y: lens.y - width * 0.11, width: width * 0.22, height: width * 0.22))
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

/// One dotted corner of an area selection: a row of dots along the top and down the left from `corner`.
func dottedCorner(_ ctx: CGContext, corner: CGPoint, leg: CGFloat, dot: CGFloat, spacing: CGFloat, color: CGColor) {
    ctx.saveGState()
    ctx.setStrokeColor(color); ctx.setLineWidth(dot); ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [0.01, spacing])
    ctx.move(to: CGPoint(x: corner.x + leg, y: corner.y))
    ctx.addLine(to: corner)
    ctx.addLine(to: CGPoint(x: corner.x, y: corner.y - leg))
    ctx.strokePath()
    ctx.restoreGState()
}

/// The app icon: a white camera with one dotted selection corner above it.
func appIcon(_ size: CGFloat) -> CGContext {
    let ctx = context(size)
    let rect = background(ctx, size: size)
    let side = rect.width
    camera(ctx, center: CGPoint(x: rect.midX + side * 0.04, y: rect.midY - side * 0.05), width: side * 0.50, color: white)
    let dot = side * 0.055
    let r = rect.insetBy(dx: side * 0.17, dy: side * 0.17)
    dottedCorner(ctx, corner: CGPoint(x: r.minX, y: r.maxY), leg: side * 0.40, dot: dot, spacing: dot * 2.1, color: rgb(1, 1, 1, 0.85))
    return ctx
}

/// The menu bar glyph: the app icon's camera and dotted corner, small. `scale` 1 or 2 for an 18 pt image.
func menuBarGlyph(scale s: CGFloat) -> CGContext {
    let ctx = context(18 * s)
    camera(ctx, center: CGPoint(x: 10 * s, y: 7.5 * s), width: 12 * s, color: black)
    dottedCorner(ctx, corner: CGPoint(x: 2 * s, y: 16 * s), leg: 7 * s, dot: 1.9 * s, spacing: 3.5 * s, color: black)
    return ctx
}

try save(appIcon(1024), "AppIcon-source.png")
try save(menuBarGlyph(scale: 1), "MenuBarIcon.png")
try save(menuBarGlyph(scale: 2), "MenuBarIcon@2x.png")
