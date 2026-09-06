//
//  InteractiveChartView.swift
//  Newton
//
//  Native chart visualizer for structured data, bar charts, and trends.
//

import SwiftUI

public struct ChartDataPoint: Identifiable {
    public let id = UUID()
    public let label: String
    public let value: Double
    
    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

public struct InteractiveChartView: View {
    public let title: String
    public let chartType: String
    public let dataPoints: [ChartDataPoint]
    
    public init(title: String, chartType: String = "bar", dataPoints: [ChartDataPoint]) {
        self.title = title
        self.chartType = chartType
        self.dataPoints = dataPoints
    }
    
    private var maxValue: Double {
        max(dataPoints.map { $0.value }.max() ?? 1.0, 1.0)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "chart.bar.fill")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(NewtonTheme.sand)
                Spacer()
                Text(chartType.capitalized)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
            
            // Bar Columns
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(dataPoints) { dp in
                    VStack(spacing: 6) {
                        Text(String(format: "%.0f", dp.value))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(NewtonTheme.sand)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [NewtonTheme.sand, NewtonTheme.forestGreen],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(CGFloat(dp.value / maxValue) * 100, 8))
                        
                        Text(dp.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140)
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(UIColor.separator).opacity(0.6), lineWidth: 0.8)
        )
    }
}
