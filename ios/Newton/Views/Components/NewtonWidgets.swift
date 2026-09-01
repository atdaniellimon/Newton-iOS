//
//  NewtonWidgets.swift
//  Newton
//
//  Created for Newton iOS.
//  Home Screen and Lock Screen Widgets.
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
        let entry = NewtonWidgetEntry(
            date: Date(),
            title: "Newton",
            subtitle: "What will you discover today?",
            insight: "Reasoning deeply across science, code, and creativity."
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct NewtonQuickActionWidgetView: View {
    var entry: NewtonWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    public var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.15, blue: 0.16)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Text("Newton")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Spacer()
                }
                
                Text(entry.subtitle)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(Color.white.opacity(0.8))
                    .lineLimit(2)
                
                Spacer()
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 11))
                        Text("New Chat")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(NewtonTheme.sand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    
                    Spacer()
                }
            }
            .padding(14)
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
        .configurationDisplayName("Newton Quick Actions")
        .description("Quickly open Newton to start a new chat or query.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
