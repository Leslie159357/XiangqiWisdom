import AVFoundation
import AVKit
import UIKit

/// 画中画：用 AVSampleBufferDisplayLayer 承载画面，AVPictureInPictureController 负责悬浮。
/// 开源版先用纯色帧验证链路，后续把识别叠加层渲染进 CMSampleBuffer。
final class PiPController: NSObject, AVPictureInPictureControllerDelegate,
                           AVPictureInPictureSampleBufferPlaybackDelegate {
    private let displayLayer = AVSampleBufferDisplayLayer()
    private var controller: AVPictureInPictureController?
    private var timer: Timer?
    private var format: CMVideoFormatDescription?
    private var tick = 0

    func attach(to view: UIView) {
        displayLayer.frame = view.bounds
        displayLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(displayLayer)
        view.layoutIfNeeded()

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            NSLog("[PiP] unsupported on this device")
            return
        }
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self)

        controller = AVPictureInPictureController(contentSource: source)
        controller?.delegate = self
        controller?.requiresLinearPlayback = false
    }

    func start() {
        guard let controller = controller else { return }
        startFeeding()
        controller.startPictureInPicture()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        controller?.stopPictureInPicture()
    }

    // MARK: - 帧供给

    private func startFeeding() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.enqueueFrame()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func enqueueFrame() {
        let width = 360, height = 540
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [kCVPixelBufferCGImageCompatibilityKey: true,
                                      kCVPixelBufferCGBitmapContextCompatibilityKey: true]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                            attrs as CFDictionary, &pixelBuffer)
        guard let buffer = pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                               bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
            let shade = CGFloat(Double(tick % 20) / 40.0)
            ctx.setFillColor(UIColor(red: 0.10 + shade, green: 0.22, blue: 0.14, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        if format == nil {
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: buffer,
                                                         formatDescriptionOut: &format)
        }
        guard let fmt = format else { return }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 15),
                                        presentationTimeStamp: CMTime(value: Int64(tick), timescale: 15),
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: buffer,
                                                 formatDescription: fmt,
                                                 sampleTiming: &timing,
                                                 sampleBufferOut: &sample)
        guard let s = sample else { return }
        if displayLayer.status == .failed { displayLayer.flush() }
        displayLayer.enqueue(s)
        tick += 1
    }

    // MARK: - Delegates

    func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController,
                                    didTransitionToRenderSize newSize: CMVideoDimensions) {}

    func pictureInPictureController(_ controller: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        NSLog("[PiP] started")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        NSLog("[PiP] stopped")
    }
}
