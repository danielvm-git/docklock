import AppKit
import Foundation

func generateIcon() {
    let size: CGFloat = 1024
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let image = NSImage(size: rect.size)

    image.lockFocus()

    // 1. Background Gradient (Sodalite to LockGreen)
    let sodalite = NSColor(red: 0.17, green: 0.32, blue: 0.47, alpha: 1.0)
    let lockGreen = NSColor(red: 0.39, green: 0.78, blue: 0.25, alpha: 1.0)
    let gradient = NSGradient(starting: sodalite, ending: lockGreen)

    let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    path.addClip()
    gradient?.draw(in: rect, angle: -45)

    // 2. The "Dock" bar
    let dockRect = NSRect(x: size * 0.15, y: size * 0.2, width: size * 0.7, height: size * 0.15)
    let dockPath = NSBezierPath(roundedRect: dockRect, xRadius: size * 0.04, yRadius: size * 0.04)
    NSColor.white.withAlphaComponent(0.9).set()
    dockPath.fill()

    // 3. The "Lock" arch
    let archPath = NSBezierPath()
    archPath.lineWidth = size * 0.06
    let center = NSPoint(x: size * 0.5, y: size * 0.5)
    archPath.appendArc(withCenter: center, radius: size * 0.15, startAngle: 0, endAngle: 180)
    NSColor.white.set()
    archPath.stroke()

    // 4. The Lock Base (inside dock)
    let lockBaseRect = NSRect(x: size * 0.4, y: size * 0.4, width: size * 0.2, height: size * 0.1)
    let lockBase = NSBezierPath(roundedRect: lockBaseRect, xRadius: size * 0.02, yRadius: size * 0.02)
    sodalite.set()
    lockBase.fill()

    image.unlockFocus()

    if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
        let png = bitmap.representation(using: .png, properties: [:])
        try? png?.write(to: URL(fileURLWithPath: "AppIcon.png"))
    }
}

generateIcon()
print("AppIcon.png generated.")
