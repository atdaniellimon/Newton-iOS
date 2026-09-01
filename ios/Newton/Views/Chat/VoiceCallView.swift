//
//  VoiceCallView.swift
//  Newton
//
//  Created for Newton iOS.
//  Immersive full-screen Live Voice Call mode with reactive 3D Orb.
//

import SwiftUI
import AVFoundation

public struct VoiceCallView: View {
    @ObservedObject var conversation: Conversation
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var speechService = SpeechService.shared
    @StateObject private var settings = SettingsManager.shared
    
    @State private var callStatus: String = "Connecting..."
    @State private var userSpeechBuffer: String = ""
    @State private var isProcessingResponse: Bool = false
    @State private var lastSpokenResponse: String = ""
    @State private var isMuted: Bool = false
    @State private var silenceTimer: Timer? = nil
    
    public init(conversation: Conversation) {
        self.conversation = conversation
    }
    
    public var body: some View {
        ZStack {
            // Dark Everforest deep space canvas
            Color(red: 0.10, green: 0.13, blue: 0.14)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Top Bar (Title & Dismiss)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEWTON LIVE VOICE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(NewtonTheme.sand)
                            .tracking(1.5)
                        
                        Text(callStatus)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button {
                        endCall()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Central Reactive Thinking 3D Orb (Scales with audio amplitude)
                ZStack {
                    // Pulsing Glow halo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    NewtonTheme.sand.opacity(0.35 * Double(speechService.audioLevel + 0.3)),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 180
                            )
                        )
                        .frame(width: 320, height: 320)
                        .scaleEffect(1.0 + CGFloat(speechService.audioLevel * 0.4))
                        .animation(.easeOut(duration: 0.15), value: speechService.audioLevel)
                    
                    // Thinking Orb 3D canvas
                    ThinkingOrbView()
                        .frame(width: 220, height: 220)
                        .scaleEffect(1.0 + CGFloat(speechService.audioLevel * 0.25))
                        .animation(.easeOut(duration: 0.15), value: speechService.audioLevel)
                }
                
                Spacer()
                
                // Live Transcript Subtitles Card
                VStack(spacing: 8) {
                    if isProcessingResponse {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(NewtonTheme.sand)
                            Text("Newton is formulating thought...")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(NewtonTheme.sand)
                        }
                    } else if speechService.isSpeaking {
                        Text(lastSpokenResponse)
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(Color.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .padding(.horizontal, 20)
                    } else if !speechService.liveTranscript.isEmpty {
                        Text("“\(speechService.liveTranscript)”")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(NewtonTheme.sandLight)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 20)
                    } else {
                        Text("Speak naturally, Newton is listening...")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 70)
                .padding(.horizontal, 20)
                
                // Bottom Call Controls (Mute, Speaker Waveform, End Call)
                HStack(spacing: 36) {
                    // Mute Button
                    Button {
                        toggleMute()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 22))
                                .foregroundColor(isMuted ? NewtonTheme.coralRed : .white)
                                .frame(width: 58, height: 58)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                            
                            Text(isMuted ? "Unmute" : "Mute")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // End Call (Red Button)
                    Button {
                        endCall()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 68, height: 68)
                                .background(NewtonTheme.coralRed)
                                .clipShape(Circle())
                            
                            Text("End")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Interrupt / Stop Speaking Button
                    Button {
                        speechService.stopSpeaking()
                        startUserListening()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "waveform")
                                .font(.system(size: 22))
                                .foregroundColor(NewtonTheme.sand)
                                .frame(width: 58, height: 58)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                            
                            Text("Interrupt")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            startCall()
        }
        .onDisappear {
            endCall()
        }
    }
    
    // MARK: - Voice Call Logic
    
    private func startCall() {
        Haptics.success()
        speechService.requestSpeechAuthorization { authorized in
            if authorized {
                callStatus = "Active (Connected)"
                // Welcome greeting if new conversation
                if conversation.messages.isEmpty {
                    let greeting = "Hola, soy Newton. ¿De qué te gustaría que hablemos hoy?"
                    lastSpokenResponse = greeting
                    speechService.speak(text: greeting)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        startUserListening()
                    }
                } else {
                    startUserListening()
                }
            } else {
                callStatus = "Microphone Permission Required"
            }
        }
    }
    
    private func startUserListening() {
        guard !isMuted else { return }
        callStatus = "Listening..."
        userSpeechBuffer = ""
        
        speechService.startListening { text in
            userSpeechBuffer = text
            resetSilenceTimer()
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        // Wait 1.6 seconds of silence before sending the utterance to Newton
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { _ in
            if !userSpeechBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sendUserSpeechToNewton()
            }
        }
    }
    
    private func sendUserSpeechToNewton() {
        let userPrompt = userSpeechBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userPrompt.isEmpty else { return }
        
        speechService.stopListening()
        callStatus = "Thinking..."
        isProcessingResponse = true
        
        // Append user message to conversation model
        let userMessage = Message(role: .user, content: userPrompt)
        conversation.messages.append(userMessage)
        
        Task {
            var fullResponse = ""
            let dummyAssistant = Message(role: .assistant, content: "", isStreaming: true)
            await MainActor.run {
                conversation.messages.append(dummyAssistant)
            }
            
            do {
                let stream = LLMService.shared.streamCompletion(
                    messages: conversation.messages,
                    provider: settings.currentProvider,
                    modelId: settings.currentModelId,
                    baseUrl: settings.effectiveBaseUrl(for: settings.currentProvider),
                    apiKey: settings.currentApiKey
                )
                
                for try await token in stream {
                    fullResponse += token
                }
                
                // Process tool calling
                let (finalContent, _, _) = await OrbitEngine.shared.processOrbitsInText(
                    fullResponse,
                    userPrompt: userPrompt,
                    baseUrl: settings.effectiveBaseUrl(for: settings.currentProvider),
                    apiKey: settings.currentApiKey
                )
                
                await MainActor.run {
                    if let lastIdx = conversation.messages.indices.last {
                        conversation.messages[lastIdx].content = finalContent
                        conversation.messages[lastIdx].isStreaming = false
                    }
                    StorageManager.shared.updateConversation(conversation)
                    
                    self.isProcessingResponse = false
                    self.lastSpokenResponse = finalContent
                    self.callStatus = "Newton Speaking..."
                    
                    // Speak back response
                    self.speechService.speak(text: finalContent)
                    
                    // Auto-resume listening when done speaking
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(finalContent.count) * 0.06 + 1.0) {
                        self.startUserListening()
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isProcessingResponse = false
                    self.callStatus = "Error: \(error.localizedDescription)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.startUserListening()
                    }
                }
            }
        }
    }
    
    private func toggleMute() {
        Haptics.light()
        isMuted.toggle()
        if isMuted {
            speechService.stopListening()
            callStatus = "Muted"
        } else {
            startUserListening()
        }
    }
    
    private func endCall() {
        Haptics.light()
        silenceTimer?.invalidate()
        silenceTimer = nil
        speechService.stopListening()
        speechService.stopSpeaking()
        dismiss()
    }
}
