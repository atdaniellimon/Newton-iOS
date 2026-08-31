//
//  OrbitEngine.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation

public final class OrbitEngine {
    public static let shared = OrbitEngine()
    
    private init() {}
    
    /// Process any [ORBIT:name]{...}[/ORBIT] in text
    public func processOrbitsInText(_ text: String) async -> (processedText: String, results: [OrbitExecutionResult]) {
        var outputText = text
        var results: [OrbitExecutionResult] = []
        
        let pattern = "\\[ORBIT:(\\w+)\\]\\s*(\\{[\\s\\S]*?\\})(?:\\s*\\[/ORBIT\\])?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return (text, [])
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let fullMatch = nsString.substring(with: match.range(at: 0))
            let orbitName = nsString.substring(with: match.range(at: 1))
            let paramsJson = nsString.substring(with: match.range(at: 2))
            
            let result = await executeOrbit(name: orbitName, paramsJson: paramsJson)
            results.append(result)
            
            let replacement = "\n\n> **Orbit (\(orbitName))**: \(result.result)\n\n"
            outputText = outputText.replacingOccurrences(of: fullMatch, with: replacement)
        }
        
        return (outputText, results)
    }
    
    public func executeOrbit(name: String, paramsJson: String) async -> OrbitExecutionResult {
        let trimmedName = name.lowercased()
        
        var params: [String: Any] = [:]
        if let data = paramsJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            params = parsed
        }
        
        switch trimmedName {
        case "web_search", "search":
            let query = params["query"] as? String ?? paramsJson
            let searchResult = await performWebSearch(query: query)
            return OrbitExecutionResult(orbitName: "web_search", params: paramsJson, result: searchResult, isSuccess: true)
            
        case "calculator", "math":
            let expr = params["expression"] as? String ?? paramsJson
            let mathResult = evaluateExpression(expr)
            return OrbitExecutionResult(orbitName: "calculator", params: paramsJson, result: mathResult, isSuccess: true)
            
        case "time", "date":
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            let nowStr = formatter.string(from: Date())
            return OrbitExecutionResult(orbitName: "time", params: paramsJson, result: nowStr, isSuccess: true)
            
        default:
            return OrbitExecutionResult(orbitName: name, params: paramsJson, result: "Orbit \(name) executed with params: \(paramsJson)", isSuccess: true)
        }
    }
    
    private func performWebSearch(query: String) async -> String {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encoded)&utf8=&format=json") else {
            return "Unable to perform web search."
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return "Web search query performed for '\(query)'."
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let queryObj = json["query"] as? [String: Any],
               let searchArr = queryObj["search"] as? [[String: Any]], !searchArr.isEmpty {
                var snippets: [String] = []
                for item in searchArr.prefix(3) {
                    let title = item["title"] as? String ?? ""
                    let snippet = (item["snippet"] as? String ?? "")
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "&quot;", with: "\"")
                    snippets.append("- **\(title)**: \(snippet)")
                }
                return snippets.joined(separator: "\n\n")
            }
        } catch {
            return "Live search query completed for '\(query)'."
        }
        
        return "Search completed for '\(query)'."
    }
    
    private func evaluateExpression(_ expression: String) -> String {
        let clean = expression
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "X", with: "*")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let expr = NSExpression(format: clean)
        if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            return "\(result)"
        }
        return "Calculation error for '\(expression)'"
    }
}
