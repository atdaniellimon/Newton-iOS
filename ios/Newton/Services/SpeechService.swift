//
//  SpeechService.swift
//  Newton
//
//  Created for Newton iOS.
//  Handles speech recognition (STT), audio metering, and speech synthesis (TTS).
//

import Foundation
import AVFoundation
import Speech
import SwiftUI

public final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = SpeechService()
    
    // TTS
    private let synthesizer = AVSpeechSynthesizer()
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
    
    // MARK: - Text-to-Speech (TTS)
    
    public func speak(text: String, messageId: String? = nil) {
        stopSpeaking()
        
        // Clean markdown syntax from spoken text
        let cleanText = text
            .replacingOccurrences(of: "\\[ORBIT:[^\\]]+\\][\\s\\S]*?\\[/ORBIT\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "```[\\s\\S]*?```", with: "Bloque de código.", options: .regularExpression)
            .replacingOccurrences(of: "[*#_`~>]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        
        // Match language
        if cleanText.contains("the ") || cleanText.contains("and ") || cleanText.contains("is ") {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "es-MX") ?? AVSpeechSynthesisVoice(language: "es-ES")
        }
        
        self.currentlySpeakingMessageId = messageId
        self.isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
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
    
    // AVSpeechSynthesizerDelegate
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentlySpeakingMessageId = nil
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
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
            
            // Calculate audio amplitude level for 3D orb reactive motion
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
