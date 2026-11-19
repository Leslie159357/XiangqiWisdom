import Foundation

/// 象棋云库（chessdb.cn）客户端。
/// 原版云端开局库走的就是这个接口：GET queryall，无签名、无 token。
struct CloudBookMove {
    let move: String
    let score: Int
    let winrate: Double
    let drawrate: Double
    let lossrate: Double
}

final class CloudBook {
    static let shared = CloudBook()
    private let session = URLSession(configuration: .ephemeral)

    /// fen 传入不带 " w - - 0 1" 后缀的棋盘部分
    func queryAll(fen: String, completion: @escaping ([CloudBookMove]) -> Void) {
        var comps = URLComponents(string: "https://www.chessdb.cn/chessdb.php")
        comps?.queryItems = [
            URLQueryItem(name: "action", value: "queryall"),
            URLQueryItem(name: "board", value: fen)
        ]
        guard let url = comps?.url else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        session.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let text = String(data: data, encoding: .utf8) ?? ""
            var moves: [CloudBookMove] = []
            for part in text.split(separator: "|") {
                var map: [String: String] = [:]
                for field in part.split(separator: ",") {
                    let kv = field.split(separator: ":", maxSplits: 1)
                    if kv.count == 2 { map[String(kv[0])] = String(kv[1]) }
                }
                guard let m = map["move"], let s = Int(map["score"] ?? "0") else { continue }
                moves.append(CloudBookMove(move: m, score: s,
                                           winrate: Double(map["winrate"] ?? "0") ?? 0,
                                           drawrate: Double(map["drawrate"] ?? "0") ?? 0,
                                           lossrate: Double(map["lossrate"] ?? "0") ?? 0))
            }
            DispatchQueue.main.async { completion(moves) }
        }.resume()
    }
}
