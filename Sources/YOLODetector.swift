import CoreML
import Foundation
import UIKit

/// 通用 Ultralytics YOLO CoreML 推理器（MultiArray 输出：confidence[N,C] + coordinates[N,4]）
final class YOLODetector {
    private let model: MLModel
    private let labels: [String]
    private let inputSize = 640
    private let confidenceThreshold: Double

    init?(modelName: String, labels: [String], confidenceThreshold: Double = 0.25) {
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
        guard let buffer = resized.pixelBuffer(width: inputSize, height: inputSize) else { return [] }

        let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "image": MLFeatureValue(pixelBuffer: buffer),
            "iouThreshold": MLFeatureValue(double: 0.45),
            "confidenceThreshold": MLFeatureValue(double: confidenceThreshold)
        ])
        guard let input = provider,
              let output = try? model.prediction(from: input),
              let confidence = output.featureValue(for: "confidence")?.multiArrayValue,
              let coordinates = output.featureValue(for: "coordinates")?.multiArrayValue else {
            return []
        }

        let count = confidence.shape[0].intValue
        let classCount = confidence.shape.count > 1 ? confidence.shape[1].intValue : labels.count
        guard count > 0 else { return [] }

        var raw: [Detection] = []
        for i in 0..<count {
            var bestClass = 0
            var bestScore: Float = 0
            for c in 0..<min(classCount, labels.count) {
                let score = confidence[[i, c]].floatValue
                if score > bestScore {
                    bestScore = score
                    bestClass = c
                }
            }
            guard Double(bestScore) >= confidenceThreshold else { continue }

            let cx = coordinates[[i, 0]].doubleValue
            let cy = coordinates[[i, 1]].doubleValue
            let w = coordinates[[i, 2]].doubleValue
            let h = coordinates[[i, 3]].doubleValue
            let rect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
            raw.append(Detection(label: labels[bestClass], confidence: bestScore, rect: rect))
        }
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
