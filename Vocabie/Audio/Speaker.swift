import Foundation
import AVFoundation
import Observation

/// Speaks vocabulary aloud using Apple's built-in speech synthesis — the same voices
/// Translate, VoiceOver and Speak Screen use. Free, on-device, no network.
///
/// Two things this handles that are easy to miss:
/// 1. **The silent switch.** By default synthesized speech obeys the ringer switch, so a
///    learner studying with their phone muted hears nothing. Category `.playback` plays
///    through it.
/// 2. **Voice quality.** The stock voice is mediocre. If the user has downloaded an
///    enhanced or premium voice (설정 → 손쉬운 사용 → 음성 콘텐츠) we pick it automatically.
@MainActor
@Observable
final class Speaker: NSObject {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()
    private var categoryConfigured = false

    /// True while an utterance is playing — views use it to animate the speaker icon.
    private(set) var isSpeaking = false

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Speaking

    /// Speaks `text`. Slightly slower than conversational pace, which suits single words.
    func speak(_ text: String, language: String = "en-US") {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return }

        activateSession()

        // Cut off whatever is playing so rapid card flips don't queue up.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = bestVoice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.postUtteranceDelay = 0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        deactivateSession()
    }

    // MARK: Audio session

    /// `.playback` is what makes speech audible with the ringer switch off.
    /// `.duckOthers` dips background music instead of killing it, so studying to music works.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if !categoryConfigured {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                categoryConfigured = true
            }
            try session.setActive(true)
        } catch {
            // Audio is a nice-to-have; never let it break studying.
            #if DEBUG
            print("Speaker: audio session activation failed — \(error)")
            #endif
        }
    }

    /// Releasing the session lets ducked music return to full volume.
    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance()
                .setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            #if DEBUG
            print("Speaker: audio session deactivation failed — \(error)")
            #endif
        }
    }

    // MARK: Voice selection

    /// Picks the best voice the device actually has for this language.
    /// Quality ranks premium > enhanced > default; enhanced and premium are user downloads.
    private func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(language.prefix(2)).lowercased()
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix(prefix)
        }
        guard !candidates.isEmpty else {
            return AVSpeechSynthesisVoice(language: language)
        }

        // Prefer an exact locale match, then the highest quality available.
        let exact = candidates.filter { $0.language.caseInsensitiveCompare(language) == .orderedSame }
        let pool = exact.isEmpty ? candidates : exact
        return pool.max { $0.quality.rawValue < $1.quality.rawValue }
    }

    /// Whether the user has any upgraded voice installed for this language.
    /// Views use this to offer a one-time "download a better voice" tip.
    func hasUpgradedVoice(for language: String = "en-US") -> Bool {
        let prefix = String(language.prefix(2)).lowercased()
        return AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.lowercased().hasPrefix(prefix)
                && $0.quality.rawValue > AVSpeechSynthesisVoiceQuality.default.rawValue
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension Speaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.deactivateSession()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
