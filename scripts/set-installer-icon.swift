import AppKit
import Foundation

// Native file-icon composition: preserve the compiled app identity and add
// macOS's package badge. The signed application and DMG data fork stay intact.
// Distribute with ditto --sequesterRsrc to preserve this Finder metadata.
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift set-installer-icon.swift APP.icns INSTALLER.dmg")
}
let target = CommandLine.arguments[2]
guard target.hasSuffix(".dmg"), FileManager.default.fileExists(atPath: target),
      let app = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let box = NSImage(contentsOfFile: "/System/Library/CoreServices/Installer.app/Contents/Resources/package.icns") else {
    fatalError("Expected an app icon, a DMG and the native package icon")
}
let icon = NSImage(size: NSSize(width: 512, height: 512))
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = icon.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    app.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512))
    box.draw(in: NSRect(x: 314, y: 0, width: 198, height: 198))
    NSGraphicsContext.restoreGraphicsState()
    icon.addRepresentation(rep)
}
guard NSWorkspace.shared.setIcon(icon, forFile: target, options: []) else {
    fatalError("Finder icon assignment failed")
}
print("Assigned app-primary icon with lower-right package badge")
