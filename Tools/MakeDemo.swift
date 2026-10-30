import Foundation
import AVFoundation
import CoreGraphics
import CoreText

// Original stereo scene generated at build time. Each eye projects the same
// moving objects from a different horizontal camera, converging at z = 6.
let destination = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Cinema/Resources/Aurora-FSBS.mp4"
let url = URL(fileURLWithPath: destination)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
let width = 1280, height = 360, fps: Int32 = 24, count = 720
let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2400000]])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
writer.add(input)
guard writer.startWriting() else { fatalError(writer.error!.localizedDescription) }
writer.startSession(atSourceTime: .zero)
let colorspace = CGColorSpaceCreateDeviceRGB()
let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 14, nil)

for frame in 0..<count {
    while !input.isReadyForMoreMediaData {
        if writer.status == .failed { fatalError(writer.error!.localizedDescription) }
        Thread.sleep(forTimeInterval: 0.002)
    }
    try autoreleasepool {
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        guard let buffer else { fatalError("No video buffer") }
        CVPixelBufferLockBaseAddress(buffer, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: colorspace,
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        let t = Double(frame) / Double(fps)
        for eye in 0..<2 {
            ctx.saveGState()
            ctx.translateBy(x: CGFloat(eye * 640), y: 0)
            ctx.clip(to: CGRect(x: 0, y: 0, width: 640, height: 360))
            ctx.setFillColor(CGColor(red: 0.009, green: 0.023, blue: 0.043, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            let eyeX = eye == 0 ? -0.11 : 0.11
            func project(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
                CGPoint(x: 320 + x * 360 / z + eyeX * 360 * (1 / 6.0 - 1 / z), y: 180 + y * 360 / z)
            }
            for star in 0..<90 {
                let z = 9 + Double(star % 17)
                let x = Double((star * 79) % 211 - 105) / 9
                let y = Double((star * 37) % 113 - 56) / 10
                let p = project(x, y, z)
                ctx.setFillColor(CGColor(gray: 0.55 + Double(star % 4) * 0.1, alpha: 1))
                ctx.fillEllipse(in: CGRect(x: p.x, y: p.y, width: 1.5, height: 1.5))
            }
            for object in 0..<3 {
                let z = object == 0 ? 12 : (object == 1 ? 7.5 : 4.4 + sin(t * 0.6) * 0.8)
                let x = object == 2 ? sin(t * 0.5) * 1.6 : (object == 0 ? -4.1 : 2.7)
                let y = object == 2 ? cos(t * 0.7) * 0.45 : (object == 0 ? 1.6 : -0.3)
                let p = project(x, y, z)
                let radius = (object == 2 ? 0.62 : 0.8) * 360 / z
                let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
                ctx.saveGState()
                ctx.addEllipse(in: rect)
                ctx.clip()
                let gradient = CGGradient(colorsSpace: colorspace, colors: [
                    CGColor(red: 0.38, green: 0.96, blue: 0.81, alpha: 1),
                    CGColor(red: 0.015, green: 0.15, blue: 0.24, alpha: 1)] as CFArray, locations: [0, 1])!
                ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
                ctx.restoreGState()
                ctx.setStrokeColor(CGColor(red: 0.94, green: 0.66, blue: 0.33, alpha: 1))
                ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: rect.insetBy(dx: -radius * 0.5, dy: radius * 0.5))
            }
            let title = NSAttributedString(string: "AURORA  /  TESTE 3D · \(eye == 0 ? "ESQUERDO" : "DIREITO")", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.9, alpha: 1)])
            ctx.textPosition = CGPoint(x: 24, y: 326)
            CTLineDraw(CTLineCreateWithAttributedString(title as CFAttributedString), ctx)
            ctx.restoreGState()
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps)) else {
            throw writer.error ?? NSError(domain: "Demo", code: 1)
        }
    }
}
input.markAsFinished()
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
guard writer.status == .completed else { fatalError(writer.error!.localizedDescription) }
print("Generated original Full SBS 3D demo: \(url.lastPathComponent)")
