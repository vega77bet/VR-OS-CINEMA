import AppKit

let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Cinema/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let colors = [NSColor(calibratedRed: 0.035, green: 0.15, blue: 0.19, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.01, green: 0.035, blue: 0.065, alpha: 1).cgColor]
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
context.setStrokeColor(NSColor(calibratedRed: 0.89, green: 0.65, blue: 0.38, alpha: 1).cgColor)
context.setLineWidth(15)
context.addPath(CGPath(roundedRect: CGRect(x: 170, y: 380, width: 684, height: 420), cornerWidth: 48, cornerHeight: 48, transform: nil))
context.strokePath()
context.setFillColor(NSColor(calibratedRed: 0.10, green: 0.36, blue: 0.39, alpha: 1).cgColor)
context.addPath(CGPath(roundedRect: CGRect(x: 200, y: 410, width: 624, height: 360), cornerWidth: 32, cornerHeight: 32, transform: nil))
context.fillPath()
context.setStrokeColor(NSColor(calibratedWhite: 0.93, alpha: 1).cgColor)
context.setLineWidth(18)
context.move(to: CGPoint(x: 404, y: 500))
context.addLine(to: CGPoint(x: 512, y: 683))
context.addLine(to: CGPoint(x: 620, y: 500))
context.strokePath()
for x in [225.0, 437.0, 649.0] {
    context.setFillColor(NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.095, alpha: 1).cgColor)
    context.addPath(CGPath(roundedRect: CGRect(x: x, y: 209, width: 150, height: 220), cornerWidth: 38, cornerHeight: 38, transform: nil))
    context.fillPath()
    context.setFillColor(NSColor(calibratedRed: 0.64, green: 0.40, blue: 0.24, alpha: 1).cgColor)
    context.fill(CGRect(x: x + 12, y: 202, width: 126, height: 7))
}
let image = context.makeImage()!
let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
try data.write(to: directory.appendingPathComponent("AppIcon.png"))
let manifest: [String: Any] = ["images": [["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]],
                               "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: directory.appendingPathComponent("Contents.json"))
print("Generated original Cinema app icon")
