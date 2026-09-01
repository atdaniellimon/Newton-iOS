//
//  NewtonLiveActivityWidget.swift
//  Newton
//
//  Created for Newton iOS.
//  Dynamic Island and Lock Screen Live Activity Widget Views.
//

import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.2, *)
public struct NewtonLiveActivityWidgetView: View {
    let context: ActivityViewContext<NewtonActivityAttributes>
    
    public init(context: ActivityViewContext<NewtonActivityAttributes>) {
        self.context = context
    }
    
    public var body: some View {
        // Lock Screen Banner UI
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NewtonTheme.sand.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: context.attributes.activityType == "image_gen" ? "paintpalette.fill" : "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(NewtonTheme.sand)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(context.state.title)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if context.state.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(NewtonTheme.forestGreen)
                    } else {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(NewtonTheme.sand)
                    }
                }
                
                Text(context.state.status)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(NewtonTheme.sand)
                            .frame(width: max(geo.size.width * CGFloat(context.state.progress), 6), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(red: 0.12, green: 0.15, blue: 0.16))
    }
}

@available(iOS 16.2, *)
public struct NewtonLiveActivityWidget: Widget {
    public let kind: String = "NewtonLiveActivityWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: NewtonActivityAttributes.self) { context in
            // Lock Screen / Notification Center
            NewtonLiveActivityWidgetView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island UI (Long-press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.attributes.activityType == "image_gen" ? "paintpalette.fill" : "lightbulb.fill")
                            .font(.system(size: 14))
                            .foregroundColor(NewtonTheme.sand)
                        Text(context.state.title)
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(NewtonTheme.forestGreen)
                            .padding(.trailing, 8)
                    } else {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(NewtonTheme.sand)
                            .padding(.trailing, 8)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.status)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(2)
                        
                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 3.5)
                                Capsule()
                                    .fill(NewtonTheme.sand)
                                    .frame(width: max(geo.size.width * CGFloat(context.state.progress), 8), height: 3.5)
                            }
                        }
                        .frame(height: 3.5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                // Compact Leading (Left of camera pill)
                HStack(spacing: 3) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.sand)
                    Text("Newton")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                // Compact Trailing (Right of camera pill)
                if context.state.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(NewtonTheme.forestGreen)
                } else {
                    ProgressView()
                        .scaleEffect(0.55)
                        .tint(NewtonTheme.sand)
                }
            } minimal: {
                // Minimal (Separate island circle)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.sand)
            }
        }
    }
}
