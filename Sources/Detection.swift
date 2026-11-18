import CoreGraphics
import Foundation
import UIKit

struct Detection {
    let label: String
    let confidence: Float
    /// 归一化坐标（0-1，原点左上）
    let rect: CGRect
}

enum YOLOPostProcess {
    /// 按类别做 NMS
    static func nms(_ input: [Detection], iouThreshold: Float = 0.45) -> [Detection] {
        var result: [Detection] = []
        let grouped = Dictionary(grouping: input, by: { $0.label })
        for (_, group) in grouped {
            var remaining = group.sorted { $0.confidence > $1.confidence }
            while let best = remaining.first {
                result.append(best)
                remaining.removeFirst()
                remaining = remaining.filter { iou(best.rect, $0.rect) < iouThreshold }
            }
        }
        return result.sorted { $0.confidence > $1.confidence }
    }

    static func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let inter = a.intersection(b)
        guard !inter.isNull else { return 0 }
        let interArea = inter.width * inter.height
        let union = a.width * a.height + b.width * b.height - interArea
        guard union > 0 else { return 0 }
        return Float(interArea / union)
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// RGB 像素缓冲，用于 CoreML 图像输入
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        guard let buffer = pixelBuffer,
              let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        guard let cg = cgImage else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
