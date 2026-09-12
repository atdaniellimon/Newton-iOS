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
        
        // TTS: use system AVSpeechSynthesizer (Newton native Enhanced Neural voice)
        playAppleEnhancedTTS(cleanText: cleanText)
    }
    
    private func playAppleEnhancedTTS(cleanText: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.rate = Float(SettingsManager.shared.speechRate)
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
    
    public var onSpeechFinished: (() -> Void)? = nil
    
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
            self.onSpeechFinished?()
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentlySpeakingMessageId = nil
            self.onSpeechFinished?()
        }
    }
    
    // MARK: - Speech-to-Text (STT) & Microphone Metering
    
    public func requestSpeechAuthorization(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
            guard micGranted else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
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
        inputNode.removeTap(onBus: 0)
        
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
        guard recordingFormat.sampleRate > 0 else { return }
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
