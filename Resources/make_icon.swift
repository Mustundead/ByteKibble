// swift make_icon.swift <输出目录>
// 生成 ClashQuota 应用图标：渐变圆角底 + 猫粮图标（catfood.svg）
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// 背景：圆角矩形 + 蓝→紫渐变（macOS 图标内容区约占 1024 的 82%）
let inset: CGFloat = 100
let bg = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
ctx.addPath(CGPath(roundedRect: bg, cornerWidth: 185, cornerHeight: 185, transform: nil))
ctx.clip()
let colors = [CGColor(srgbRed: 0.28, green: 0.50, blue: 0.98, alpha: 1),
              CGColor(srgbRed: 0.60, green: 0.35, blue: 0.96, alpha: 1)] as CFArray
let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

// 猫粮图标：经 AppKit 渲染 SVG（CoreSVG），再以 CGImage 画到渐变上
let svgPath = URL(fileURLWithPath: #filePath)          // <项目>/Resources/make_icon.swift
    .deletingLastPathComponent()                        // <项目>/Resources
    .deletingLastPathComponent()                        // <项目>
    .appendingPathComponent("Sources/ClashQuota/Resources/catfood.svg").path
guard let svgImg = NSImage(contentsOf: URL(fileURLWithPath: svgPath)) else {
    fatalError("找不到 catfood.svg：\(svgPath)")
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
svgImg.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), from: .zero,
            operation: .copy, fraction: 1.0)
gctx.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
if let glyph = rep.cgImage {
    // 图形占内容区约 66%，居中
    let side: CGFloat = 560
    ctx.draw(glyph, in: CGRect(x: (S - side) / 2, y: (S - side) / 2, width: side, height: side))
}

let img = ctx.makeImage()!
let pngURL = URL(fileURLWithPath: outDir).appendingPathComponent("icon_1024.png") as CFURL
let dest = CGImageDestinationCreateWithURL(pngURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("PNG 写入失败") }
print("icon_1024.png 已生成")
