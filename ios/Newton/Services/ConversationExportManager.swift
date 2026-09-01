//
//  ConversationExportManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Generates multi-page editorial PDFs and Markdown transcripts.
//

import Foundation
import UIKit
import SwiftUI

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
    
    // MARK: - Export to Editorial PDF
    
    public func exportToPDF(conversation: Conversation) -> URL? {
        let pageWidth: CGFloat = 612 // Standard US Letter (8.5 x 11 in)
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - (margin * 2)
        
        let pdfMetaData = [
            kCGPDFContextCreator: "Newton AI for iOS",
            kCGPDFContextAuthor: "Newton Singularity",
            kCGPDFContextTitle: conversation.title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(conversation.title.replacingOccurrences(of: "/", with: "-")).pdf"
        let fileUrl = tempDir.appendingPathComponent(fileName)
        
        do {
            try renderer.writePDF(to: fileUrl, withActions: { context in
                context.beginPage()
                var currentY: CGFloat = margin
                
                // Helper to check page break
                func checkPageBreak(neededHeight: CGFloat) {
                    if currentY + neededHeight > pageHeight - margin {
                        context.beginPage()
                        currentY = margin
                    }
                }
                
                // Header (Newton Branding & Document Title)
                let brandAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.88, green: 0.74, blue: 0.50, alpha: 1.0)
                ]
                "NEWTON SINGULARITY // CONVERSATION TRANSCRIPT".draw(at: CGPoint(x: margin, y: currentY), withAttributes: brandAttributes)
                currentY += 18
                
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "Georgia-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20),
                    .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.20, alpha: 1.0)
                ]
                let titleRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 50)
                conversation.title.draw(in: titleRect, withAttributes: titleAttributes)
                currentY += 32
                
                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
                "Generated on \(Date().formatted(date: .complete, time: .shortened))".draw(at: CGPoint(x: margin, y: currentY), withAttributes: dateAttributes)
                currentY += 20
                
                // Divider line
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: currentY))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
                UIColor(red: 0.82, green: 0.79, blue: 0.74, alpha: 0.8).setStroke()
                path.lineWidth = 1
                path.stroke()
                currentY += 20
                
                // Messages
                for msg in conversation.messages {
                    let isUser = msg.role == .user
                    
                    // Role Tag
                    let roleTitle = isUser ? "USER" : "NEWTON"
                    let roleAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                        .foregroundColor: isUser ? UIColor(red: 0.65, green: 0.55, blue: 0.35, alpha: 1.0) : UIColor(red: 0.35, green: 0.55, blue: 0.50, alpha: 1.0)
                    ]
                    checkPageBreak(neededHeight: 30)
                    roleTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: roleAttributes)
                    currentY += 16
                    
                    // Body text
                    if !msg.content.isEmpty {
                        let bodyAttributes: [NSAttributedString.Key: Any] = [
                            .font: isUser ? UIFont.systemFont(ofSize: 12) : (UIFont(name: "Georgia", size: 12) ?? UIFont.systemFont(ofSize: 12)),
                            .foregroundColor: UIColor(red: 0.15, green: 0.18, blue: 0.20, alpha: 1.0)
                        ]
                        
                        let bounding = NSString(string: msg.content).boundingRect(
                            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: bodyAttributes,
                            context: nil
                        )
                        
                        checkPageBreak(neededHeight: bounding.height + 16)
                        msg.content.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: bounding.height), withAttributes: bodyAttributes)
                        currentY += bounding.height + 16
                    }
                    
                    // Embedded Image if present
                    if let imgStr = msg.imageUrl, let uiImg = imgStr.decodeBase64ToUIImage() {
                        let imgHeight: CGFloat = min(uiImg.size.height * (contentWidth / uiImg.size.width), 220)
                        checkPageBreak(neededHeight: imgHeight + 20)
                        
                        uiImg.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: imgHeight))
                        currentY += imgHeight + 20
                    }
                    
                    currentY += 8
                }
            })
            return fileUrl
        } catch {
            print("PDF generation error: \(error)")
            return nil
        }
    }
}
