import Foundation
import CoreGraphics

/// 把检测结果映射成象棋 FEN。
/// 前提：BoardDetector 的 `bd` 框给出棋盘区域，棋子检测框中心落在 9×10 网格。
/// 第一版按矩形归一化投影，不做透视校正（斜视角会偏移，后续用四点单应修）。
enum FENMapper {
    static let boardLabels: Set<String> = ["bd", "dk", "dt"]

    /// label → FEN 字符（红大写 / 黑小写）
    static func fenChar(_ label: String) -> String? {
        guard let side = label.first else { return nil }
        let type = String(label.dropFirst())
        let table: [String: String] = [
            "c": "R", "h": "N", "e": "B", "g": "A", "k": "K", "p": "C", "s": "P"
        ]
        guard let ch = table[type] else { return nil }
        return side == "r" ? ch : ch.lowercased()
    }

    static func fen(from detections: [Detection]) -> String? {
        guard let board = detections.first(where: { $0.label == "bd" }) else { return nil }
        let rect = board.rect
        guard rect.width > 0, rect.height > 0 else { return nil }

        var grid = Array(repeating: Array(repeating: "", count: 9), count: 10)

        for d in detections where !boardLabels.contains(d.label) {
            guard let ch = fenChar(d.label) else { continue }
            let nx = (d.rect.midX - rect.minX) / rect.width
            let ny = (d.rect.midY - rect.minY) / rect.height
            guard (0...1).contains(nx), (0...1).contains(ny) else { continue }
            let col = min(8, max(0, Int(nx * 9)))
            let row = min(9, max(0, Int(ny * 10)))
            if grid[row][col].isEmpty { grid[row][col] = ch }
        }

        var rows: [String] = []
        for row in 0..<10 {
            var s = ""
            var empty = 0
            for col in 0..<9 {
                let ch = grid[row][col]
                if ch.isEmpty {
                    empty += 1
                } else {
                    if empty > 0 { s += "\(empty)"; empty = 0 }
                    s += ch
                }
            }
            if empty > 0 { s += "\(empty)" }
            rows.append(s)
        }
        return rows.joined(separator: "/") + " w - - 0 1"
    }
}
