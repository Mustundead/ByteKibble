import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let source = CGImageSourceCreateWithURL(input as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let mode = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "edge"
if mode == "stats" || mode == "stats-left" {
    let rep = NSBitmapImageRep(cgImage: image)
    for y in stride(from: 180, through: 660, by: 40) {
        let candidates = (mode == "stats" ? 655..<742 : 175..<285).map { x -> (Int, Double) in
            let a = rep.colorAt(x: x - 2, y: y)!.usingColorSpace(.sRGB)!
            let b = rep.colorAt(x: x + 2, y: y)!.usingColorSpace(.sRGB)!
            return (x, Double(b.blueComponent - a.blueComponent))
        }.sorted { $0.1 > $1.1 }
        print(y, candidates.prefix(3))
    }
    exit(0)
}
let crop: CGImage
if mode == "detail" { crop = image.cropping(to: CGRect(x: 620, y: 740, width: 270, height: 160))! }
else if mode == "source" { crop = image.cropping(to: CGRect(x: 635, y: 140, width: 110, height: 590))! }
else { crop = image }
let w = mode == "detail" ? 810 : mode == "source" ? 330 : 1024
let h = mode == "detail" ? 480 : mode == "source" ? 1770 : 1024
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(gray: mode == "white" ? 1 : 0, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
ctx.interpolationQuality = .high
ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
precondition(CGImageDestinationFinalize(dest))
