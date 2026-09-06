//
//  FileAttachment.swift
//  Newton
//
//  Model representing a visual, structured file attachment in a message.
//

import Foundation

public struct FileAttachment: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let fileName: String
    public let fileExtension: String
    public let fileSizeFormatted: String
    public let lineCount: Int?
    public let previewSnippet: String?
    public let mimeType: String
    public let isImage: Bool
    public let base64Data: String?
    public let localPath: String?
    
    public init(
        id: String = UUID().uuidString,
        fileName: String,
        fileExtension: String,
        fileSizeFormatted: String,
        lineCount: Int? = nil,
        previewSnippet: String? = nil,
        mimeType: String = "text/plain",
        isImage: Bool = false,
        base64Data: String? = nil,
        localPath: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileExtension = fileExtension.lowercased()
        self.fileSizeFormatted = fileSizeFormatted
        self.lineCount = lineCount
        self.previewSnippet = previewSnippet
        self.mimeType = mimeType
        self.isImage = isImage
        self.base64Data = base64Data
        self.localPath = localPath
    }
    
    public var iconName: String {
        switch fileExtension {
        case "swift", "c", "cpp", "h", "py", "js", "ts", "html", "css", "rs", "go", "java":
            return "chevron.left.forwardslash.chevron.right"
        case "pdf":
            return "doc.richtext.fill"
        case "json", "xml", "yaml", "yml", "plist", "toml":
            return "curlybraces"
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg":
            return "photo.fill"
        case "mp3", "wav", "m4a", "aac":
            return "waveform"
        case "zip", "tar", "gz", "dmg", "ipa":
            return "doc.zipper"
        case "md", "markdown", "txt":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }
}
