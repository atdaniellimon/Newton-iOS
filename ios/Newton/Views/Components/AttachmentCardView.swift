//
//  AttachmentCardView.swift
//  Newton
//
//  Native, rich visual card component for file attachments.
//

import SwiftUI

public struct AttachmentCardView: View {
    public let attachment: FileAttachment
    @State private var showingPreviewSheet: Bool = false
    
    public init(attachment: FileAttachment) {
        self.attachment = attachment
    }
    
    public var body: some View {
        Button(action: {
            showingPreviewSheet = true
            Haptics.light()
        }) {
            HStack(spacing: 12) {
                // File Type Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(NewtonTheme.sand.opacity(0.15))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: attachment.iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.fileName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(attachment.fileExtension.uppercased())
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(NewtonTheme.sand)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(NewtonTheme.sand.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Text(attachment.fileSizeFormatted)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        
                        if let lines = attachment.lineCount {
                            Text("• \(lines) lines")
                                .font(.system(size: 11))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPreviewSheet) {
            AttachmentPreviewSheet(attachment: attachment)
        }
    }
}

struct AttachmentPreviewSheet: View {
    let attachment: FileAttachment
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(attachment.fileName, systemImage: attachment.iconName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(NewtonTheme.sand)
                            Spacer()
                            Text(attachment.fileSizeFormatted)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        if let preview = attachment.previewSnippet, !preview.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Content Preview")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                
                                Text(preview)
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(NewtonTheme.sand)
                }
            }
        }
    }
}
