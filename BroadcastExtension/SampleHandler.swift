import ReplayKit
import UIKit
import CoreImage

/// ReplayKit 广播扩展：接收系统录屏帧，缩到 640 宽后以 JPEG 通过 UDP 发给主 App。
/// 扩展内存上限约 50MB，这里全程只做一次 CIContext 缩放 + JPEG 编码。
final class SampleHandler: RPBroadcastSampleHandler {
    private var socketFD: Int32 = -1
    private let port: UInt16 = 9527
    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var frameCount = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        NSLog("[Broadcast] started, socket=%d", socketFD)
    }

    override func broadcastPaused() {
        NSLog("[Broadcast] paused")
    }

    override func broadcastResumed() {
        NSLog("[Broadcast] resumed")
    }

    override func broadcastFinished() {
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
        NSLog("[Broadcast] finished")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 每 5 帧发一次，减少扩展内存与带宽压力
        frameCount += 1
        guard frameCount % 5 == 0 else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scale = 640.0 / max(1, ciImage.extent.width)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = ciContext.createCGImage(scaled, from: scaled.extent) else { return }
        let image = UIImage(cgImage: cg)
        guard let jpeg = image.jpegData(compressionQuality: 0.35) else { return }
        send(jpeg)
    }

    private func send(_ data: Data) {
        guard socketFD >= 0 else { return }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    _ = sendto(socketFD, base, data.count, 0, sa, UInt32(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}
