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
                
                Image(systemName: context.attributes.activityType == "image_gen" ? "paintpalette.fill" : "sparkles")
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
