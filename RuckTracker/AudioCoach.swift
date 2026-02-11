import AVFoundation
import Combine

// MARK: - ⚠️ FUTURE FEATURE — Not yet integrated
// This class exists but is never called from any view or workout tracker.
// See docs/FUTURE_FEATURES.md for implementation plan.
class AudioCoach: NSObject, ObservableObject {
    static let shared = AudioCoach()
    private let synthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()
    
    var isEnabled: Bool = true
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Audio Coach Session Error: \(error)")
        }
    }
    
    func speak(_ text: String) {
        guard isEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
    
    func announceSplit(mile: Int, pace: String) {
        // Runna Style: Clear, concise data.
        let text = "Mile \(mile). Pace: \(pace)."
        speak(text)
    }
    
    func announceMilestone(distance: Double) {
        if distance == 6.0 {
            speak("6 Miles complete. Halfway to 12. Check your hydration.")
        } else if distance == 12.0 {
            speak("12 Miles complete. Standard achieved.")
        }
    }
}

