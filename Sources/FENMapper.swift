import Foundation
import CoreGraphics

/// 把检测结果映射成象棋 FEN。
///
/// 坐标系与原版 `ViewController::indexForTouchPoint:boardSize:` 对齐：
///   格宽 = boardWidth / 8   （9 条竖线 → 8 个间隔）
///   格高 = boardHeight / 9  （10 条横线 → 9 个间隔）
///   col = round((x - minX) / cellW) ∈ 0..8
///   row = round((y - minY) / cellH) ∈ 0..9
/// 原版还会对 `bd` 框做 UIEdgeInsets 内缩；这里按 2% 近似，避免边框把
/// 边缘棋子推到格子外。
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

    /// 棋盘内缩 + 8/9 间隔取整
    private static func cell(row: Bool, x: CGFloat, y: CGFloat, rect: CGRect) -> Int {
        if row {
            let cellH = rect.height / 9
            return min(9, max(0, Int(((y - rect.minY) / cellH).rounded())))
        } else {
            let cellW = rect.width / 8
            return min(8, max(0, Int(((x - rect.minX) / cellW).rounded())))
        }
    }

    private static func boardRect(_ rect: CGRect) -> CGRect {
        let dx = rect.width * 0.02
        let dy = rect.height * 0.02
        return rect.insetBy(dx: dx, dy: dy)
    }

    /// 输出 10×9 字符矩阵（空格为空位），供 Zobrist 计算
    static func board(from detections: [Detection]) -> [[Character]]? {
        guard let board = detections.first(where: { $0.label == "bd" }) else { return nil }
        let rect = boardRect(board.rect)
        guard rect.width > 0, rect.height > 0 else { return nil }

        var grid = Array(repeating: Array(repeating: Character(" "), count: 9), count: 10)
        for d in detections where !boardLabels.contains(d.label) {
            guard let ch = fenChar(d.label)?.first else { continue }
            let x = d.rect.midX
            let y = d.rect.midY
            guard rect.contains(CGPoint(x: x, y: y)) else { continue }
            let col = cell(row: false, x: x, y: y, rect: rect)
            let r = cell(row: true, x: x, y: y, rect: rect)
            if grid[r][col] == " " { grid[r][col] = ch }
        }
        return grid
    }

    static func fen(from detections: [Detection]) -> String? {
        guard let grid = board(from: detections) else { return nil }

        var rows: [String] = []
        for r in 0..<10 {
            var s = ""
            var empty = 0
            for c in 0..<9 {
                let ch = grid[r][c]
                if ch == " " {
                    empty += 1
                } else {
                    if empty > 0 { s += "\(empty)"; empty = 0 }
                    s += String(ch)
                }
            }
            if empty > 0 { s += "\(empty)" }
            rows.append(s)
        }
        return rows.joined(separator: "/") + " w - - 0 1"
    }
}
