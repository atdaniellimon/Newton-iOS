//
//  NewtonAppIntents.swift
//  Newton
//
//  AppIntents & Shortcuts integration for Action Button and Siri.
//

import AppIntents
import SwiftUI

public struct StartVoiceCallIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Newton Voice Call"
    public static var description = IntentDescription("Immediately starts a real-time hands-free voice call with Newton Singularity.")
    public static var openAppWhenRun: Bool = true
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        return .result()
    }
}

public struct AddMemoryIntent: AppIntent {
    public static var title: LocalizedStringResource = "Save Memory to Newton"
    public static var description = IntentDescription("Saves a permanent fact or instruction to Newton's long-term memory.")
    
    @Parameter(title: "Memory Content")
    var content: String
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "No se proporcionó ningún recuerdo para guardar.")
        }
        
        MemoryManager.shared.addMemory(trimmed)
        return .result(dialog: "Recuerdo guardado permanentemente en Newton Singularity.")
    }
}
