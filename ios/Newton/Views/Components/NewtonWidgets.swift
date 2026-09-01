//
//  NewtonWidgets.swift
//  Newton
//
//  Created for Newton iOS.
//  Home Screen and Lock Screen Widgets with deep link actions.
//

import SwiftUI
import WidgetKit

public struct NewtonWidgetEntry: TimelineEntry {
    public let date: Date
    public let title: String
    public let subtitle: String
    public let insight: String
}

public struct NewtonWidgetProvider: TimelineProvider {
    public func placeholder(in context: Context) -> NewtonWidgetEntry {
        NewtonWidgetEntry(
            date: Date(),
            title: "Newton Singularity",
            subtitle: "What will you discover today?",
            insight: "Thinking is the dialogue of the soul with itself."
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (NewtonWidgetEntry) -> Void) {
        let entry = NewtonWidgetEntry(
            date: Date(),
            title: "Newton Singularity",
            subtitle: "Ready to assist you",
            insight: "Ask anything with deep reasoning and live tools."
        )
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<NewtonWidgetEntry>) -> Void) {
        let insights = [
            "Reasoning deeply across science, code, and creativity.",
            "Formulate your hypothesis and test it against data.",
            "Simplicity is the ultimate sophistication.",
            "All truth is simple in the mind that sees it clearly."
        ]
        let randomInsight = insights.randomElement() ?? "What will you discover today?"
        
        let entry = NewtonWidgetEntry(
            date: Date(),
            title: "Newton Singularity",
            subtitle: "Ready to assist",
            insight: randomInsight
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct NewtonQuickActionWidgetView: View {
    var entry: NewtonWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    public var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.12, blue: 0.14)
                .ignoresSafeArea()
            
            switch family {
            case .systemSmall:
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(NewtonTheme.sand.opacity(0.18))
                                .frame(width: 26, height: 26)
                            Image(systemName: "sparkles")
                                .font(.system(size: 13))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        
                        Spacer()
                        
                        Text("LIVE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(NewtonTheme.forestGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(NewtonTheme.forestGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Text("Newton")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Text(entry.insight)
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.75))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Link(destination: URL(string: "newton://new")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("New Chat")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundColor(NewtonTheme.sand)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(12)
                
            case .systemMedium:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(NewtonTheme.sand)
                            Text("Newton Singularity")
                                .font(.system(size: 14, weight: .bold, design: .serif))
                                .foregroundColor(NewtonTheme.textPrimary)
                        }
                        
                        Spacer()
                        
                        Text("ENGINE ACTIVE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(NewtonTheme.forestGreen)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(NewtonTheme.forestGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Text("\"\(entry.insight)\"")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Link(destination: URL(string: "newton://new")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 10))
                                Text("New Chat")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(NewtonTheme.sand)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        Link(destination: URL(string: "newton://ghost")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "ghost.fill")
                                    .font(.system(size: 10))
                                Text("Ghost")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 0.80, green: 0.65, blue: 0.98))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.80, green: 0.65, blue: 0.98).opacity(0.14))
                            .clipShape(Capsule())
                        }
                        
                        Link(destination: URL(string: "newton://voice")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 10))
                                Text("Voice")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(NewtonTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                }
                .padding(14)
                
            default:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Newton")
                        .font(.headline)
                    Text("Ready")
                        .font(.subheadline)
                }
            }
        }
    }
}

public struct NewtonQuickActionWidget: Widget {
    public let kind: String = "NewtonQuickActionWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewtonWidgetProvider()) { entry in
            NewtonQuickActionWidgetView(entry: entry)
        }
        .configurationDisplayName("Newton Singularity")
        .description("Quick actions for new conversations, ghost sessions, and voice calls.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
