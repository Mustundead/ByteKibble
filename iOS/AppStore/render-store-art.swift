import AppKit

// Compose a new marketing layout. Original UI captures are never retouched.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("output/app-store-imagegen/composed-v2")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let backgroundPath = "output/app-store-imagegen/graphite-amber-background.png"
let entries: [(String, String, String, String)] = [
    ("01-allowance", "剩余流量，一眼看清", "Your remaining data, at a glance", "output/acceptance/ios-demo-qa-launch.png"),
    ("02-sync", "Mac 上选好，iPhone 上查看", "Choose on Mac. Check on iPhone.", "output/ios-sync-ui-english-captures/CA2B790F-DEEE-4AD1-9915-4BBC1202A64C.png"),
    ("03-export", "用量记录，随时导出", "Keep your usage records", "output/ios-history-accepted-captures/56E539FF-AADD-4D43-B35C-C0482EE6A061.png")
]
guard let background = NSImage(contentsOf: root.appendingPathComponent(backgroundPath)) else { fatalError("Missing generated background") }
var manifest: [[String: Any]] = []
for (slug, zh, en, source) in entries {
    guard let screenshot = NSImage(contentsOf: root.appendingPathComponent(source)) else { fatalError("Missing original capture: \(source)") }
    for (locale, headline) in [("zh-Hans", zh), ("en-US", en)] {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1290, pixelsHigh: 2796, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot allocate export") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: 1290, height: 2796).fill()
        background.draw(in: NSRect(x: 0, y: 0, width: 1290, height: 2796))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var size: CGFloat = 88
        var attributes: [NSAttributedString.Key: Any] = [:]
        repeat {
            attributes = [.font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: paragraph]
            if (headline as NSString).size(withAttributes: attributes).width <= 1140 { break }
            size -= 1
        } while size > 48
        (headline as NSString).draw(in: NSRect(x: 75, y: 2405, width: 1140, height: 145), withAttributes: attributes)
        // Same center and maximum bounds on all six exports; aspect ratio preserved.
        let bounds = NSRect(x: 175, y: 200, width: 940, height: 2040)
        let ratio = min(bounds.width / screenshot.size.width, bounds.height / screenshot.size.height)
        let fitted = NSSize(width: screenshot.size.width * ratio, height: screenshot.size.height * ratio)
        let frame = NSRect(x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
        NSColor(calibratedWhite: 0.3, alpha: 1).setFill()
        NSBezierPath(roundedRect: frame.insetBy(dx: -5, dy: -5), xRadius: 5, yRadius: 5).fill()
        screenshot.draw(in: frame)
        NSGraphicsContext.restoreGraphicsState()
        let filename = "\(slug)-\(locale).png"
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG export failed") }
        try png.write(to: output.appendingPathComponent(filename))
        manifest.append(["file": filename, "locale": locale, "headline": headline, "sourceScreenshot": source, "background": backgroundPath, "width": 1290, "height": 2796, "uiRetouched": false, "status": "candidate-not-uploaded", "note": "Source capture language retained; review locale suitability before upload."])
        print(filename)
    }
}
let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("manifest.json"))
