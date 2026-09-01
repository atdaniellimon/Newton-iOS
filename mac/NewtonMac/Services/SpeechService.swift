//
//  SpeechService.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import Foundation
import AppKit
import AVFoundation

public final class SpeechService: NSObject, ObservableObject, NSSpeechSynthesizerDelegate {
    public static let shared = SpeechService()
    
    private var synthesizer = NSSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    @Published public var isSpeaking: Bool = false
    @Published public var currentlySpeakingMessageId: String? = nil
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    public func toggleSpeech(for messageId: String, text: String, baseUrl: String = "", apiKey: String = "") {
        if isSpeaking && currentlySpeakingMessageId == messageId {
            stopSpeech()
        } else {
            speak(text: text, messageId: messageId, baseUrl: baseUrl, apiKey: apiKey)
        }
    }
    
    public func speak(text: String, messageId: String? = nil, baseUrl: String = "", apiKey: String = "") {
        stopSpeech()
        
        let cleanText = text
            .replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[ORBIT:[\\w\\-_]+\\][\\s\\S]*?(?:\\[/ORBIT\\]|$)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "```[\\s\\S]*?```", with: "Código omitido.", options: .regularExpression)
            .replacingOccurrences(of: "[#*_`]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else { return }
        
        self.currentlySpeakingMessageId = messageId
        self.isSpeaking = true
        
        // 1. Check if neural TTS endpoint is available
        if !baseUrl.isEmpty && !baseUrl.contains("localhost") && !apiKey.isEmpty {
            Task {
                if let data = await requestNeuralTTS(text: cleanText, baseUrl: baseUrl, apiKey: apiKey) {
                    await MainActor.run {
                        do {
                            self.audioPlayer = try AVAudioPlayer(data: data)
                            self.audioPlayer?.play()
                        } catch {
                            self.fallbackMacTTS(text: cleanText)
                        }
                    }
                    return
                }
                await MainActor.run {
                    self.fallbackMacTTS(text: cleanText)
                }
            }
        } else {
            fallbackMacTTS(text: cleanText)
        }
    }
    
    private func fallbackMacTTS(text: String) {
        synthesizer.startSpeaking(text)
    }
    
    private func requestNeuralTTS(text: String, baseUrl: String, apiKey: String) async -> Data? {
        let cleanBase = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointStr = cleanBase.hasSuffix("/v1") ? "\(cleanBase)/audio/speech" : "\(cleanBase)/v1/audio/speech"
        guard let url = URL(string: endpointStr) else { return nil }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 8
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "tts-1",
            "input": String(text.prefix(1500)),
            "voice": "nova",
            "response_format": "mp3"
        ]
        
        guard let postData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        req.httpBody = postData
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            return data
        }
        return nil
    }
    
    public func stopSpeech() {
        synthesizer.stopSpeaking()
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        currentlySpeakingMessageId = nil
    }
    
    public func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking success: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentlySpeakingMessageId = nil
        }
    }
}
