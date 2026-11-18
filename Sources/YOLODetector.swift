import CoreML
import Foundation
import UIKit

/// 通用 Ultralytics YOLO CoreML 推理器。
/// 兼容两种输出布局：confidence[N,C] / coordinates[N,4]，以及带 batch 维的 [1,N,C] / [1,N,4]。
final class YOLODetector {
    private let model: MLModel
    private let labels: [String]
    private let inputSize = 640
    private let confidenceThreshold: Double

    init?(modelName: String, labels: [String], confidenceThreshold: Double = 0.20) {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: url, configuration: MLModelConfiguration()) else {
            return nil
        }
        self.model = model
        self.labels = labels
        self.confidenceThreshold = confidenceThreshold
    }

    func detect(in image: UIImage) -> [Detection] {
        let resized = image.resized(to: CGSize(width: inputSize, height: inputSize))
        guard let buffer = resized.pixelBuffer(width: inputSize, height: inputSize) else {
            NSLog("[YOLO] pixelBuffer failed")
            return []
        }

        let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "image": MLFeatureValue(pixelBuffer: buffer),
            "iouThreshold": MLFeatureValue(double: 0.45),
            "confidenceThreshold": MLFeatureValue(double: confidenceThreshold)
        ])
        guard let input = provider,
              let output = try? model.prediction(from: input),
              let confidence = output.featureValue(for: "confidence")?.multiArrayValue,
              let coordinates = output.featureValue(for: "coordinates")?.multiArrayValue else {
            NSLog("[YOLO] prediction failed")
            return []
        }

        let confDims = confidence.shape
        let coordDims = coordinates.shape
        let confBatched = confDims.count == 3
        let coordBatched = coordDims.count == 3
        let nConf = Int(truncating: confBatched ? confDims[1] : confDims[0])
        let nCoord = Int(truncating: coordBatched ? coordDims[1] : coordDims[0])
        let n = min(nConf, nCoord)
        NSLog("[YOLO] conf=%@ coord=%@ n=%d", "\(confDims)", "\(coordDims)", n)
        guard n > 0 else { return [] }

        func conf(_ i: Int, _ c: Int) -> Float {
            if confBatched {
                return confidence[[NSNumber(value: 0), NSNumber(value: i), NSNumber(value: c)]].floatValue
            }
            return confidence[[NSNumber(value: i), NSNumber(value: c)]].floatValue
        }
        func coord(_ i: Int, _ k: Int) -> Double {
            if coordBatched {
                return coordinates[[NSNumber(value: 0), NSNumber(value: i), NSNumber(value: k)]].doubleValue
            }
            return coordinates[[NSNumber(value: i), NSNumber(value: k)]].doubleValue
        }

        var raw: [Detection] = []
        for i in 0..<n {
            var bestClass = 0
            var bestScore: Float = 0
            for c in 0..<labels.count {
                let score = conf(i, c)
                if score > bestScore {
                    bestScore = score
                    bestClass = c
                }
            }
            guard Double(bestScore) >= confidenceThreshold else { continue }

            let cx = coord(i, 0)
            let cy = coord(i, 1)
            let w = coord(i, 2)
            let h = coord(i, 3)
            // Ultralytics 坐标可能是归一化 0-1，也可能是 640 像素；统一归一化
            let scale: Double = (max(w, h) > 2.0) ? 1.0 / Double(inputSize) : 1.0
            let rect = CGRect(x: (cx - w / 2) * scale,
                              y: (cy - h / 2) * scale,
                              width: w * scale,
                              height: h * scale)
            raw.append(Detection(label: labels[bestClass], confidence: bestScore, rect: rect))
        }
        NSLog("[YOLO] raw=%d afterNMS=%d", raw.count, YOLOPostProcess.nms(raw).count)
        return YOLOPostProcess.nms(raw)
    }
}

/// 本工程使用的四个模型与类别名（与作者导出的 metadata 对齐）
enum Models {
    static let boardLabels = ["bc", "rc", "bh", "rh", "be", "re", "bg", "rg",
                              "bk", "rk", "bp", "rp", "bs", "rs", "dk", "dt", "bd"]
    static let pieceLabels = ["bc", "rc", "bh", "rh", "be", "re", "bg", "rg",
                              "bk", "rk", "bp", "rp", "bs", "rs", "ph"]

    static func board() -> YOLODetector? {
        YOLODetector(modelName: "BoardDetector", labels: boardLabels)
    }
    static func pieces() -> YOLODetector? {
        YOLODetector(modelName: "PieceDetector", labels: pieceLabels)
    }
}
