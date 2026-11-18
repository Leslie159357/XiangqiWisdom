import Foundation

/// 本地 Pikafish 引擎封装（C++ 静态链接，NNUE 走 CPU）
final class PikafishEngine {
    static let shared = PikafishEngine()
    private(set) var ready = false

    func initialize(threads: Int = 2, hashMB: Int = 256) {
        guard !ready else { return }
        guard let nnue = Bundle.main.path(forResource: "pikafish", ofType: "nnue") else {
            NSLog("[Pikafish] nnue not found in bundle")
            return
        }
        let rc = pf_init(nnue, Int32(threads), Int32(hashMB))
        ready = (rc == 0)
        NSLog("[Pikafish] init rc=%d ready=%d", rc, ready ? 1 : 0)
    }

    func bestMove(fen: String, depth: Int = 16) -> String? {
        guard ready else { return nil }
        let result = fen.withCString { ptr -> String? in
            guard let out = pf_bestmove(ptr, Int32(depth)) else { return nil }
            defer { free(out) }
            let s = String(cString: out)
            return s.isEmpty ? nil : s
        }
        return result
    }

    /// UCI 着法（h2e2）→ 中文着法（炮二平五）的极简转换，仅覆盖常见情况
    static func chineseMove(_ uci: String) -> String {
        return uci
    }
}
