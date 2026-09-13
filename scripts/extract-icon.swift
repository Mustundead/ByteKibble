import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let source = CGImageSourceCreateWithURL(input as CFURL, nil)!
let original = CGImageSourceCreateImageAtIndex(source, 0, nil)!
// The approved sheet contains two appearances. Work only on the complete left icon.
let left = original.cropping(to: CGRect(x: 0, y: 0, width: 890, height: original.height))!
let context = CIContext()
let maskWidth = left.width, maskHeight = left.height
// The approved raster's silhouette is smooth. Use a native Bezier matte to avoid
// model-mask stair steps being amplified by Icon Composer's specular/refraction.
let smooth = CGContext(data: nil, width: maskWidth * 4, height: maskHeight * 4, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
smooth.scaleBy(x: 4, y: 4)
smooth.setFillColor(CGColor(gray: 0, alpha: 1))
smooth.fill(CGRect(x: 0, y: 0, width: maskWidth, height: maskHeight))
smooth.translateBy(x: 0, y: CGFloat(maskHeight)); smooth.scaleBy(x: 1, y: -1)
let p = CGMutablePath()
func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func curve(_ x: CGFloat, _ y: CGFloat, _ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) {
    p.addCurve(to: point(x, y), control1: point(a, b), control2: point(c, d))
}
p.move(to: point(320, 140))
curve(637, 143, 408, 139, 564, 141.5)
curve(665.5, 164, 653, 143, 662, 148)
// Fit to measured source-image transitions, inset 1.5–2px to exclude baked backdrop.
curve(691.5, 300, 668, 209, 681, 260)
curve(725, 460, 705, 354, 717, 407)
curve(732.5, 620, 733, 513, 733, 574)
curve(711, 662, 731, 641, 725, 652)
// Keep the orange lower rim, excluding the baked brown ground-shadow strip.
curve(592, 718, 682, 679, 624, 707)
// Match the side's outgoing slope and the front base's incoming slope: no notch.
curve(573, 723, 584, 720.75, 580, 723.8)
curve(204, 677, 465, 712, 279, 688)
curve(186, 653, 191, 675, 187, 665)
curve(185, 620, 184, 645, 184, 635)
curve(192, 540, 187, 585, 189, 560)
curve(206, 460, 195, 512, 200, 481)
curve(228, 380, 212, 432, 219, 403)
curve(260, 300, 237, 357, 247, 327)
curve(280, 252, 269, 279, 275, 264)
curve(275, 225, 273, 248, 273, 236)
curve(291, 158, 277, 194, 281, 172)
curve(320, 140, 299, 144, 308, 140)
p.closeSubpath()
smooth.addPath(p); smooth.setFillColor(CGColor(gray: 1, alpha: 1)); smooth.fillPath()
let mask = CIImage(cgImage: smooth.makeImage()!).transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))
let image = CIImage(cgImage: left).applyingFilter("CIBlendWithMask", parameters: [
    kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: CIImage(cgImage: left).extent),
    kCIInputMaskImageKey: mask
])
let cutout = context.createCGImage(image, from: image.extent)!.cropping(to: CGRect(x: 174, y: 130, width: 570, height: 605))!
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let canvas = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
canvas.interpolationQuality = .high
canvas.draw(cutout, in: CGRect(x: 154, y: 132, width: 716, height: 760))
let final = canvas.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, final, nil)
precondition(CGImageDestinationFinalize(destination))
let pixels = canvas.data!.assumingMemoryBound(to: UInt8.self)
let transparent = (0..<(1024 * 1024)).filter { pixels[$0 * 4 + 3] == 0 }.count
print("Transparent pixels: \(transparent) of 1048576")
print(output.path)
