//
//  SpeechService.swift
//  Newton
//
//  Created for Newton iOS.
//  Handles natural speech recognition (STT), audio metering, and neural TTS speech synthesis.
//

import Foundation
import AVFoundation
import Speech
import SwiftUI

public final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    public static let shared = SpeechService()
    
    // TTS
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    @Published public var isSpeaking: Bool = false
    @Published public var currentlySpeakingMessageId: String? = nil
    
    // STT & Audio Metering
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published public var isListening: Bool = false
    @Published public var liveTranscript: String = ""
    @Published public var audioLevel: Float = 0.0
    
    public override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Natural Human-Like Text-to-Speech (TTS)
    
    public func speak(text: String, messageId: String? = nil) {
        stopSpeaking()
        
        // Clean markdown and tool syntax
        let cleanText = text
            .replacingOccurrences(of: "\\[ORBIT:[^\\]]+\\][\\s\\S]*?\\[/ORBIT\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "```[\\s\\S]*?```", with: "Bloque de código.", options: .regularExpression)
            .replacingOccurrences(of: "[*#_`~>]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else { return }
        
        self.currentlySpeakingMessageId = messageId
        self.isSpeaking = true
        
        // 1. Try Neural OpenAI/Proxy TTS if available
        let settings = SettingsManager.shared
        let baseUrl = settings.effectiveBaseUrl(for: settings.currentProvider)
        let apiKey = settings.currentApiKey
        
        if !baseUrl.isEmpty && (baseUrl.contains("openai.com") || baseUrl.contains("openrouter") || baseUrl.contains("8765") || baseUrl.contains("8000")) {
            Task {
                if let audioData = await fetchNeuralTTS(text: cleanText, baseUrl: baseUrl, apiKey: apiKey) {
                    await playAudioData(audioData)
                    return
                } else {
                    await MainActor.run {
                        self.playAppleEnhancedTTS(cleanText: cleanText)
                    }
                }
            }
        } else {
            playAppleEnhancedTTS(cleanText: cleanText)
        }
    }
    
    private func playAppleEnhancedTTS(cleanText: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.rate = 0.50
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        
        // Select best available enhanced/premium voice
        let isEnglish = cleanText.contains("the ") || cleanText.contains("and ") || cleanText.contains("is ")
        let targetLocale = isEnglish ? "en-US" : "es-MX"
        
        let allVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: isEnglish ? "en" : "es") }
        
        // Prioritize premium or enhanced voices
        if let premiumVoice = allVoices.first(where: { $0.quality == .premium }) {
            utterance.voice = premiumVoice
        } else if let enhancedVoice = allVoices.first(where: { $0.quality == .enhanced }) {
            utterance.voice = enhancedVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: targetLocale) ?? AVSpeechSynthesisVoice(language: "es-ES")
        }
        
        synthesizer.speak(utterance)
    }
    
    private func fetchNeuralTTS(text: String, baseUrl: String, apiKey: String) async -> Data? {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let ttsEndpoint = cleanBase.hasSuffix("/v1") ? "\(cleanBase)/audio/speech" : "\(cleanBase)/v1/audio/speech"
        
        guard let url = URL(string: ttsEndpoint) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let payload: [String: Any] = [
            "model": "tts-1",
            "input": text.prefix(1000),
            "voice": "nova"
        ]
        
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty {
                return data
            }
        } catch {
            return nil
        }
        return nil
    }
    
    @MainActor
    private func playAudioData(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            self.isSpeaking = true
        } catch {
            playAppleEnhancedTTS(cleanText: "")
        }
    }
    
    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        self.isSpeaking = false
        self.currentlySpeakingMessageId = nil
    }
    
    public func toggleSpeech(for messageId: String, text: String) {
        if isSpeaking && currentlySpeakingMessageId == messageId {
            stopSpeaking()
        } else {
            speak(text: text, messageId: messageId)
        }
    }
    
    // Delegates
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentlySpeakingMessageId = nil
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentlySpeakingMessageId = nil
        }
    }
    
    // MARK: - Speech-to-Text (STT) & Microphone Metering
    
    public func requestSpeechAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    public func startListening(onResult: @escaping (String) -> Void) {
        stopListening()
        stopSpeaking()
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcribed = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.liveTranscript = transcribed
                    onResult(transcribed)
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let channelDataValue = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            var rms: Float = 0.0
            for val in channelDataValue {
                rms += val * val
            }
            rms = sqrt(rms / Float(buffer.frameLength))
            let level = min(max(rms * 5.0, 0.0), 1.0)
            
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            self.isListening = true
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }
    
    public func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
        }
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        audioLevel = 0.0
    }
}
