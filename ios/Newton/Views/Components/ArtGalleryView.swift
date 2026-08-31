//
//  ArtGalleryView.swift
//  Newton
//
//  Created for Newton iOS.
//  Art gallery displaying Generated and Sent images across conversations.
//

import SwiftUI

public struct GalleryImageItem: Identifiable {
    public let id = UUID()
    public let imageUrl: String
    public let conversationTitle: String
    public let date: Date
    public let promptOrContent: String
    public let isGenerated: Bool
}

public struct ArtGalleryView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: Int = 0 // 0: Generated, 1: Sent / Uploaded
    @State private var previewImageString: String? = nil
    
    public init() {}
    
    private var generatedImages: [GalleryImageItem] {
        var items: [GalleryImageItem] = []
        for convo in storage.conversations {
            for msg in convo.messages where msg.role == .assistant {
                if let url = msg.imageUrl, !url.isEmpty {
                    items.append(GalleryImageItem(
                        imageUrl: url,
                        conversationTitle: convo.title,
                        date: convo.updatedAt,
                        promptOrContent: msg.content,
                        isGenerated: true
                    ))
                }
            }
        }
        return items.reversed()
    }
    
    private var sentImages: [GalleryImageItem] {
        var items: [GalleryImageItem] = []
        for convo in storage.conversations {
            for msg in convo.messages where msg.role == .user {
                if let url = msg.imageUrl, !url.isEmpty {
                    items.append(GalleryImageItem(
                        imageUrl: url,
                        conversationTitle: convo.title,
                        date: convo.updatedAt,
                        promptOrContent: msg.content,
                        isGenerated: false
                    ))
                }
            }
        }
        return items.reversed()
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    public var body: some View {
        NavigationStack {
            ZStack {
                NewtonTheme.bg
                    .ignoresSafeArea()
                
                Hero3DCanvasView()
                    .opacity(0.35)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Segmented Filter Control
                    Picker("Gallery Filter", selection: $selectedTab) {
                        Text("Generated (\(generatedImages.count))").tag(0)
                        Text("Sent / Photos (\(sentImages.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    let activeList = selectedTab == 0 ? generatedImages : sentImages
                    
                    if activeList.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: selectedTab == 0 ? "paintpalette" : "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundColor(NewtonTheme.sand.opacity(0.6))
                            
                            Text(selectedTab == 0 ? "No Generated Images Yet" : "No Sent Images Yet")
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundColor(NewtonTheme.textPrimary)
                            
                            Text(selectedTab == 0 ? "Ask Newton to 'genera una imagen de...' to create your first masterpiece." : "Attach photos to your prompts using the + menu in the chat.")
                                .font(.system(size: 14))
                                .foregroundColor(NewtonTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 36)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(activeList) { item in
                                    Button(action: {
                                        Haptics.light()
                                        previewImageString = item.imageUrl
                                    }) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            // Image Box
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(NewtonTheme.card)
                                                    .frame(height: 160)
                                                
                                                if item.imageUrl.hasPrefix("data:image/"),
                                                   let commaIndex = item.imageUrl.firstIndex(of: ","),
                                                   let data = Data(base64Encoded: String(item.imageUrl[item.imageUrl.index(after: commaIndex)...])),
                                                   let uiImg = UIImage(data: data) {
                                                    Image(uiImage: uiImg)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(height: 160)
                                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                } else if let url = URL(string: item.imageUrl) {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .empty:
                                                            ProgressView()
                                                                .tint(NewtonTheme.sand)
                                                        case .success(let image):
                                                            image
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(height: 160)
                                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                        case .failure:
                                                            Image(systemName: "exclamationmark.triangle")
                                                                .foregroundColor(NewtonTheme.coralRed)
                                                        @unknown default:
                                                            EmptyView()
                                                        }
                                                    }
                                                }
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(NewtonTheme.border, lineWidth: 0.8)
                                            )
                                            
                                            // Caption info
                                            Text(item.conversationTitle)
                                                .font(.system(size: 11.5, weight: .medium))
                                                .foregroundColor(NewtonTheme.textPrimary)
                                                .lineLimit(1)
                                                .padding(.horizontal, 2)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Art Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(NewtonTheme.sand)
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { previewImageString != nil },
                set: { if !$0 { previewImageString = nil } }
            )) {
                if let imgStr = previewImageString {
                    FullScreenImageViewer(imageString: imgStr)
                }
            }
        }
    }
}
