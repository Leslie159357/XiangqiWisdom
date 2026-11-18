import Foundation

/// 引擎抽象层。
///
/// 原版是「本地 Pikafish + 云引擎」双通道。本仓库第一版没有把 Pikafish 编译进包，
/// 因此提供两种模式：
/// 1. remoteURL 已配置 → POST {fen, depth} 到自建 UCI 网关（例如服务器上的 Pikafish HTTP 包装）
/// 2. 未配置 → demo 模式，返回内置开局着法，保证 UI 流程可验证
final class EngineBridge {
    static let shared = EngineBridge()

    /// 自建网关，示例：https://your-host/bestmove
    var remoteURL: URL?

    /// 演示用开局着法（红方先行）
    private let demoMoves = ["炮二平五", "马八进七", "兵三进一", "相三进五"]

    func bestMove(fen: String, depth: Int = 16, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = remoteURL else {
            let move = demoMoves.randomElement() ?? "炮二平五"
            completion(.success(move))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["fen": fen, "depth": depth])
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let move = json["bestmove"] as? String ?? json["move"] as? String else {
                completion(.failure(NSError(domain: "EngineBridge", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "网关返回无法解析"])))
                return
            }
            completion(.success(move))
        }.resume()
    }
}
