import CoreGraphics
import Foundation
import ImageIO

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.08, green: 0.44, blue: 0.38, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.setStrokeColor(CGColor(gray: 1, alpha: 1))
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.setLineWidth(62)
context.setLineCap(.round)
let center = CGPoint(x: 512, y: 512)
let radius: CGFloat = 235
for offset: CGFloat in [0, .pi] {
    let start = CGFloat.pi * 0.12 + offset
    let end = CGFloat.pi * 0.88 + offset
    context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    context.strokePath()
    let point = CGPoint(x: center.x + radius * cos(end), y: center.y + radius * sin(end))
    let tangent = CGPoint(x: -sin(end), y: cos(end))
    let normal = CGPoint(x: cos(end), y: sin(end))
    context.move(to: CGPoint(x: point.x + tangent.x * 72, y: point.y + tangent.y * 72))
    context.addLine(to: CGPoint(x: point.x - tangent.x * 35 + normal.x * 76, y: point.y - tangent.y * 35 + normal.y * 76))
    context.addLine(to: CGPoint(x: point.x - tangent.x * 35 - normal.x * 76, y: point.y - tangent.y * 35 - normal.y * 76))
    context.closePath()
    context.fillPath()
}
let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("无法写入图标") }
