//
//  MessageInputBar.swift
//  Newton
//
//  Created for Newton iOS.
//  Floating modern studio input bar with Camera, Photos, Files, and Web Search.
//

import SwiftUI
import UIKit

public struct MessageInputBar: View {
    @Binding public var text: String
    @Binding public var attachedImage: UIImage?
    @Binding public var attachedFileName: String?
    
    public let isStreaming: Bool
    public let modelName: String
    public let onModelTap: () -> Void
    public let onTriggerCamera: () -> Void
    public let onTriggerPhotos: () -> Void
    public let onTriggerFiles: () -> Void
    public let onTriggerWebSearch: () -> Void
    public let onSend: () -> Void
    public let onStop: () -> Void
    
    @FocusState private var isFocused: Bool
    
    public init(
        text: Binding<String>,
        attachedImage: Binding<UIImage?>,
        attachedFileName: Binding<String?>,
        isStreaming: Bool,
        modelName: String,
        onModelTap: @escaping () -> Void,
        onTriggerCamera: @escaping () -> Void,
        onTriggerPhotos: @escaping () -> Void,
        onTriggerFiles: @escaping () -> Void,
        onTriggerWebSearch: @escaping () -> Void,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self._text = text
        self._attachedImage = attachedImage
        self._attachedFileName = attachedFileName
        self.isStreaming = isStreaming
        self.modelName = modelName
        self.onModelTap = onModelTap
        self.onTriggerCamera = onTriggerCamera
        self.onTriggerPhotos = onTriggerPhotos
        self.onTriggerFiles = onTriggerFiles
        self.onTriggerWebSearch = onTriggerWebSearch
        self.onSend = onSend
        self.onStop = onStop
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                // Attached Media Preview (if image or file is attached)
                if attachedImage != nil || attachedFileName != nil {
                    HStack(spacing: 8) {
                        if let img = attachedImage {
                            HStack(spacing: 6) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text("Photo attached")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                
                                Button {
                                    Haptics.light()
                                    attachedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(NewtonTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(NewtonTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        if let fileName = attachedFileName {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(NewtonTheme.sand)
                                
                                Text(fileName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(NewtonTheme.textPrimary)
                                    .lineLimit(1)
                                
                                Button {
                                    Haptics.light()
                                    attachedFileName = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(NewtonTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(NewtonTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
                
                // Expanding text input field
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Reply to Newton...")
                            .font(.system(size: 15.5))
                            .foregroundColor(NewtonTheme.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                    }
                    
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.system(size: 15.5))
                        .foregroundColor(NewtonTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 38, maxHeight: 110)
                }
                .padding(.horizontal, 8)
                .padding(.top, 2)
                
                // Bottom Action Row: (+) [Model Badge] ... (Send/Stop)
                HStack(spacing: 8) {
                    // Modern "+" Menu: Web Search, Camera, Add Photos, Add Files
                    Menu {
                        Button(action: onTriggerWebSearch) {
                            Label("Web Search", systemImage: "globe")
                        }
                        
                        Button(action: onTriggerCamera) {
                            Label("Camera", systemImage: "camera")
                        }
                        
                        Button(action: onTriggerPhotos) {
                            Label("Add Photos", systemImage: "photo.on.rectangle")
                        }
                        
                        Button(action: onTriggerFiles) {
                            Label("Add Files", systemImage: "folder")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(NewtonTheme.surface)
                                .frame(width: 32, height: 32)
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(NewtonTheme.textSecondary)
                        }
                    }
                    
                    // Model Selector Pill Badge
                    Button(action: {
                        Haptics.selection()
                        onModelTap()
                    }) {
                        HStack(spacing: 4) {
                            Text(modelName)
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundColor(NewtonTheme.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(NewtonTheme.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(NewtonTheme.surface)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Send / Stop Button
                    Button(action: {
                        if isStreaming {
                            Haptics.medium()
                            onStop()
                        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil {
                            Haptics.light()
                            onSend()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isStreaming ? NewtonTheme.coralRed : ((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil) ? NewtonTheme.surface : NewtonTheme.sand))
                                .frame(width: 34, height: 34)
                            
                            Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isStreaming ? .white : ((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil) ? NewtonTheme.textMuted : .black))
                        }
                    }
                    .disabled(!isStreaming && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .padding(6)
            .background(NewtonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NewtonTheme.border, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .padding(.top, 4)
        }
    }
}
