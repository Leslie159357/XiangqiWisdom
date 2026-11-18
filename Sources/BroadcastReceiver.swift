import Foundation
import UIKit

/// 接收 ReplayKit 广播扩展通过 UDP(9527) 发来的 JPEG 帧
final class BroadcastReceiver {
    static let shared = BroadcastReceiver()

    var onFrame: ((UIImage) -> Void)?
    private var socketFD: Int32 = -1
    private var thread: Thread?
    private let port: UInt16 = 9527

    func start() {
        guard socketFD < 0 else { return }
        socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFD >= 0 else { return }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("0.0.0.0")
        let size = UInt32(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(socketFD, sa, size)
            }
        }
        guard bound == 0 else {
            NSLog("[Receiver] bind failed: %d", errno)
            close(socketFD)
            socketFD = -1
            return
        }

        let t = Thread { [weak self] in self?.loop() }
        t.qualityOfService = .userInitiated
        thread = t
        t.start()
        NSLog("[Receiver] listening on %d", port)
    }

    func stop() {
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
        thread = nil
    }

    private func loop() {
        var buffer = [UInt8](repeating: 0, count: 65536)
        while socketFD >= 0 {
            let n = recv(socketFD, &buffer, buffer.count, 0)
            guard n > 0 else { continue }
            let data = Data(buffer[0..<n])
            guard let image = UIImage(data: data) else { continue }
            DispatchQueue.main.async { [weak self] in
                self?.onFrame?(image)
            }
        }
    }
}
