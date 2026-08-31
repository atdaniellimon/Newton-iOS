//
//  MessageInputBar.swift
//  Newton
//
//  Created for Newton iOS.
//  Ultra-compact single-row studio input bar with auto-expanding vertical growth.
//

import SwiftUI
import UIKit
import PhotosUI

public struct MessageInputBar: View {
    @Binding public var text: String
    @Binding public var attachedImage: UIImage?
    @Binding public var attachedFileName: String?
    
    public let isStreaming: Bool
    public let modelName: String
    public let onModelTap: () -> Void
    public let onTriggerCamera: () -> Void
    public let onTriggerFiles: () -> Void
    public let onTriggerWebSearch: () -> Void
    public let onSend: () -> Void
    public let onStop: () -> Void
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @FocusState private var isFocused: Bool
    
    public init(
        text: Binding<String>,
        attachedImage: Binding<UIImage?>,
        attachedFileName: Binding<String?>,
        isStreaming: Bool,
        modelName: String,
        onModelTap: @escaping () -> Void,
        onTriggerCamera: @escaping () -> Void,
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
        self.onTriggerFiles = onTriggerFiles
        self.onTriggerWebSearch = onTriggerWebSearch
        self.onSend = onSend
        self.onStop = onStop
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            // Attached Media Preview (if image or file is selected)
            if attachedImage != nil || attachedFileName != nil {
                HStack(spacing: 8) {
                    if let img = attachedImage {
                        HStack(spacing: 6) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Image ready")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(NewtonTheme.textPrimary)
                            
                            Button {
                                Haptics.light()
                                attachedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(NewtonTheme.surface)
                        .clipShape(Capsule())
                    }
                    
                    if let fileName = attachedFileName {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 11))
                                .foregroundColor(NewtonTheme.sand)
                            
                            Text(fileName)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(NewtonTheme.textPrimary)
                                .lineLimit(1)
                            
                            Button {
                                Haptics.light()
                                attachedFileName = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(NewtonTheme.surface)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 18)
            }
            
            // Ultra-Compact Single Row Input Bar (Height ~42px)
            HStack(alignment: .center, spacing: 6) {
                // Plus Menu with native PhotosPicker & Camera
                Menu {
                    Button(action: onTriggerWebSearch) {
                        Label("Web Search", systemImage: "globe")
                    }
                    
                    Button(action: onTriggerCamera) {
                        Label("Camera", systemImage: "camera")
                    }
                    
                    // Native PhotosPicker entry
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                }
                
                // Model Selector Pill Badge
                Button(action: {
                    Haptics.selection()
                    onModelTap()
                }) {
                    HStack(spacing: 3) {
                        Text(modelName)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundColor(NewtonTheme.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7.5))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(NewtonTheme.surface)
                    .clipShape(Capsule())
                }
                
                // Native Auto-Expanding Vertical TextField
                TextField("Reply to Newton...", text: $text, axis: .vertical)
                    .focused($isFocused)
                    .lineLimit(1...5)
                    .font(.system(size: 14.5))
                    .foregroundColor(NewtonTheme.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                
                // Send / Stop Circle Button
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
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isStreaming ? .white : ((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil) ? NewtonTheme.textMuted : .black))
                    }
                }
                .disabled(!isStreaming && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(NewtonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(NewtonTheme.border, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImg = UIImage(data: data) {
                    await MainActor.run {
                        attachedImage = uiImg
                        Haptics.success()
                    }
                }
            }
        }
    }
}
