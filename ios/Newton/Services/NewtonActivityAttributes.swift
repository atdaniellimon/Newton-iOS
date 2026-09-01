//
//  NewtonActivityAttributes.swift
//  Newton
//
//  Created for Newton iOS.
//  Defines ActivityKit attributes for Dynamic Island and Lock Screen Live Activities.
//

import Foundation
import ActivityKit

public struct NewtonActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var status: String
        public var progress: Double // 0.0 to 1.0
        public var isComplete: Bool
        public var outputPreview: String?
        
        public init(title: String, status: String, progress: Double = 0.0, isComplete: Bool = false, outputPreview: String? = nil) {
            self.title = title
            self.status = status
            self.progress = progress
            self.isComplete = isComplete
            self.outputPreview = outputPreview
        }
    }
    
    public var activityType: String // "reasoning", "image_gen", "pdf_export"
    public var querySnippet: String
    
    public init(activityType: String, querySnippet: String) {
        self.activityType = activityType
        self.querySnippet = querySnippet
    }
}
