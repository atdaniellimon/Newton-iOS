//
//  ConversationExportManager.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import Foundation
import AppKit
import PDFKit

public final class ConversationExportManager {
    public static let shared = ConversationExportManager()
    
    private init() {}
    
    // MARK: - Export to Markdown
    
    public func exportToMarkdown(conversation: Conversation) -> URL? {
        var md = "# \(conversation.title)\n\n"
        md += "*Exported from Newton AI on \(Date().formatted(date: .abbreviated, time: .shortened))*\n\n---\n\n"
        
        for msg in conversation.messages {
            let roleHeader = msg.role == .user ? "### 👤 User" : "### 🔮 Newton"
            md += "\(roleHeader)\n\n"
            
            if let thinking = msg.thinkingContent, !thinking.isEmpty {
                md += "> **Thinking Process**:\n> " + thinking.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
            }
            
            if !msg.content.isEmpty {
                md += "\(msg.content)\n\n"
            }
            
            if let imgUrl = msg.imageUrl, !imgUrl.isEmpty {
                if imgUrl.hasPrefix("data:image/") {
                    md += "*(Image attached in conversation)*\n\n"
                } else {
                    md += "![Generated Image](\(imgUrl))\n\n"
                }
            }
            
            md += "---\n\n"
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(conversation.title.replacingOccurrences(of: "/", with: "-")).md"
        let fileUrl = tempDir.appendingPathComponent(fileName)
        
        do {
            try md.write(to: fileUrl, atomically: true, encoding: .utf8)
            return fileUrl
        } catch {
            print("Markdown write error: \(error)")
            return nil
        }
    }
    
    // MARK: - Generate Custom PDF Document for macOS
    
    public func generateCustomDocumentPDF(title: String, content: String) -> URL? {
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.topMargin = 44
        printInfo.bottomMargin = 44
        printInfo.leftMargin = 44
        printInfo.rightMargin = 44
        
        let cleanTitle = title.isEmpty ? "Newton_Document" : title.replacingOccurrences(of: "/", with: "-")
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("\(cleanTitle).pdf")
        
        let attrString = NSMutableAttributedString()
        
        // Header
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: NSColor(red: 0.88, green: 0.74, blue: 0.50, alpha: 1.0)
        ]
        attrString.append(NSAttributedString(string: "NEWTON REPORT // DESKTOP EDITION\n\n", attributes: headerAttr))
        
        // Title
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Georgia-Bold", size: 22) ?? NSFont.boldSystemFont(ofSize: 22),
            .foregroundColor: NSColor(red: 0.15, green: 0.18, blue: 0.20, alpha: 1.0)
        ]
        attrString.append(NSAttributedString(string: "\(title)\n\n", attributes: titleAttr))
        
        // Content
        let paragraphs = content.components(separatedBy: "\n\n")
        for para in paragraphs {
            let isHeading = para.hasPrefix("#")
            let cleanPara = para.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            
            let paraAttr: [NSAttributedString.Key: Any] = isHeading ? [
                .font: NSFont.boldSystemFont(ofSize: 14),
                .foregroundColor: NSColor(red: 0.15, green: 0.18, blue: 0.20, alpha: 1.0)
            ] : [
                .font: NSFont(name: "Georgia", size: 12) ?? NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor(red: 0.22, green: 0.25, blue: 0.28, alpha: 1.0)
            ]
            
            attrString.append(NSAttributedString(string: "\(cleanPara)\n\n", attributes: paraAttr))
        }
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 524, height: 704))
        textView.textStorage?.setAttributedString(attrString)
        
        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        do {
            try pdfData.write(to: fileUrl)
            return fileUrl
        } catch {
            print("PDF generation error: \(error)")
            return nil
        }
    }
}
