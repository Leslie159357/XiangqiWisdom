import Foundation

/// Zobrist 实现，与作者 `ZobristUtils` 逐字节对齐（已用初始局面校准：
/// 算出的 key 7101337512282506414 能在 bhobk 里查出 8 条着法）。
final class Zobrist {
    static let shared = Zobrist()

    private var table: [UInt64] = []
    private var coord: [Int32] = []
    private let redXor: UInt64 = 0xa0ce2af90c452f58

    /// 棋子字符 → pieceId（红 K=0…P=6，黑 k=7…p=13）
    private let pieceIds: [Character: Int] = [
        "K": 0, "A": 1, "B": 2, "N": 3, "R": 4, "C": 5, "P": 6,
        "k": 7, "a": 8, "b": 9, "n": 10, "r": 11, "c": 12, "p": 13
    ]

    private init() {}

    func load() {
        guard table.isEmpty else { return }
        guard let tURL = Bundle.main.url(forResource: "zobrist_table", withExtension: "bin"),
              let cURL = Bundle.main.url(forResource: "coord_map", withExtension: "bin"),
              let tData = try? Data(contentsOf: tURL),
              let cData = try? Data(contentsOf: cURL) else {
            NSLog("[Zobrist] table not found in bundle")
            return
        }
        table = tData.withUnsafeBytes { raw -> [UInt64] in
            let count = raw.count / 8
            var out = [UInt64](repeating: 0, count: count)
            for i in 0..<count { out[i] = raw.loadUnaligned(fromByteOffset: i * 8, as: UInt64.self) }
            return out
        }
        coord = cData.withUnsafeBytes { raw -> [Int32] in
            let count = raw.count / 4
            var out = [Int32](repeating: 0, count: count)
            for i in 0..<count { out[i] = raw.loadUnaligned(fromByteOffset: i * 4, as: Int32.self) }
            return out
        }
        NSLog("[Zobrist] loaded %d entries, coord %d", table.count, coord.count)
    }

    /// board 为 10×9 字符矩阵，空位为空格；棋子字符同 FEN（大写红、小写黑）
    func key(board: [[Character]], redGo: Bool) -> UInt64? {
        guard table.count >= 8192, coord.count >= 90 else { return nil }
        var k: UInt64 = 0
        for r in 0..<10 {
            for c in 0..<9 {
                let ch = board[r][c]
                if ch == " " { continue }
                guard let pid = pieceIds[ch] else { continue }
                let idx = Int(coord[r * 9 + c]) + pid * 0x100
                guard idx >= 0, idx < table.count else { continue }
                k ^= table[idx]
            }
        }
        if redGo { k ^= redXor }
        return k
    }

    /// 格号 → (行, 列)
    func cell(_ code: Int) -> (row: Int, col: Int)? {
        let r = (code >> 4) - 3
        let c = (code & 0x0F) - 3
        guard (0..<10).contains(r), (0..<9).contains(c) else { return nil }
        return (r, c)
    }

    /// UCI 风格着法坐标：格号 → "h2e2"
    func uciMove(vmove: UInt64) -> String? {
        let from = Int((vmove >> 8) & 0xFF)
        let to = Int(vmove & 0xFF)
        guard let a = cell(from), let b = cell(to) else { return nil }
        let fileNames = Array("abcdefghi")
        return "\(fileNames[a.col])\(9 - a.row)\(fileNames[b.col])\(9 - b.row)"
    }
}
