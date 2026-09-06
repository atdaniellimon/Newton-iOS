//
//  InteractiveChartView.swift
//  Newton
//
//  Native chart visualizer for structured data, bar charts, and trends.
//

import SwiftUI

public struct ChartDataPoint: Identifiable, Codable {
    public var id: String { label }
    public let label: String
    public let value: Double
    
    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

public struct InteractiveChartPayload: Codable {
    public let title: String
    public let chartType: String
    public let data: [ChartDataPoint]
    
    public init(title: String, chartType: String = "bar", data: [ChartDataPoint]) {
        self.title = title
        self.chartType = chartType
        self.data = data
    }
}

public struct InteractiveChartView: View {
    public let data: InteractiveChartPayload
    
    public init(data: InteractiveChartPayload) {
        self.data = data
    }
    
    private var maxValue: Double {
        max(data.data.map { $0.value }.max() ?? 1.0, 1.0)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(data.title, systemImage: "chart.bar.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(NewtonTheme.sand)
                Spacer()
                Text(data.chartType.capitalized)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Bar Columns
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data.data) { dp in
                    VStack(spacing: 5) {
                        Text(String(format: "%.0f", dp.value))
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(NewtonTheme.sand)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [NewtonTheme.sand, NewtonTheme.forestGreen],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(CGFloat(dp.value / maxValue) * 90, 6))
                        
                        Text(dp.label)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
            .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.8)
        )
    }
    
    public static func extractChartData(from text: String) -> InteractiveChartPayload? {
        // Match ```chart ... ``` JSON blocks
        let pattern = #"```chart\s*([\s\S]*?)\s*```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else { return nil }
        
        let jsonStr = nsString.substring(with: match.range(at: 1))
        guard let jsonData = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(InteractiveChartPayload.self, from: jsonData)
    }
}
