import Foundation
import AVFoundation

/// 语音提示：中文播报着法与状态。
final class VoiceCoach {
    private let synthesizer = AVSpeechSynthesizer()

    func say(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.46
        synthesizer.speak(utterance)
    }
}
