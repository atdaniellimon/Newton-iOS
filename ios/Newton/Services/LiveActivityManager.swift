//
//  LiveActivityManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Controls Dynamic Island and Lock Screen Live Activities.
//

import Foundation
import ActivityKit
import SwiftUI

public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()
    
    #if canImport(ActivityKit)
    private var currentActivity: Activity<NewtonActivityAttributes>?
    #endif
    
    private init() {}
    
    public func startActivity(type: String, query: String, initialStatus: String = "Reasoning...") {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        endCurrentActivity()
        
        let attributes = NewtonActivityAttributes(activityType: type, querySnippet: String(query.prefix(40)))
        let initialState = NewtonActivityAttributes.ContentState(
            title: type == "image_gen" ? "Generating Artwork" : (type == "pdf_export" ? "Compiling PDF" : "Newton Singularity"),
            status: initialStatus,
            progress: 0.1,
            isComplete: false
        )
        
        do {
            let activity = try Activity<NewtonActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
        #endif
    }
    
    public func updateActivity(status: String, progress: Double, isComplete: Bool = false, preview: String? = nil) {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else { return }
        
        let updatedState = NewtonActivityAttributes.ContentState(
            title: activity.attributes.activityType == "image_gen" ? "Generating Artwork" : "Newton Singularity",
            status: status,
            progress: progress,
            isComplete: isComplete,
            outputPreview: preview
        )
        
        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
            if isComplete {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await activity.end(.init(state: updatedState, staleDate: nil), dismissalPolicy: .immediate)
                self.currentActivity = nil
            }
        }
        #endif
    }
    
    public func endCurrentActivity() {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
        #endif
    }
}
