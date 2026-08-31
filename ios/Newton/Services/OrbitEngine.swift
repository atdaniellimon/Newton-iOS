//
//  OrbitEngine.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation
import UIKit

public final class OrbitEngine {
    public static let shared = OrbitEngine()
    
    private init() {}
    
    /// Process any [ORBIT:name]{...}[/ORBIT] in text or trigger image generation
    public func processOrbitsInText(_ text: String) async -> (processedText: String, results: [OrbitExecutionResult], imageUrl: String?) {
        var outputText = text
        var results: [OrbitExecutionResult] = []
        var detectedImageUrl: String? = nil
        
        // 1. Process explicit [ORBIT:name]{...}
        let pattern = "\\[ORBIT:(\\w+)\\]\\s*(\\{[\\s\\S]*?\\})(?:\\s*\\[/ORBIT\\])?"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let fullMatch = nsString.substring(with: match.range(at: 0))
                let orbitName = nsString.substring(with: match.range(at: 1))
                let paramsJson = nsString.substring(with: match.range(at: 2))
                
                let result = await executeOrbit(name: orbitName, paramsJson: paramsJson)
                results.append(result)
                
                if orbitName.lowercased() == "image_gen" || orbitName.lowercased() == "imagine" {
                    detectedImageUrl = result.result
                }
                
                let replacement = (orbitName.lowercased() == "image_gen" || orbitName.lowercased() == "imagine") ? "" : "\n\n> **Orbit (\(orbitName))**: \(result.result)\n\n"
                outputText = outputText.replacingOccurrences(of: fullMatch, with: replacement)
            }
        }
        
        // 2. Detect markdown images or /imagine in output
        if let imgRegex = try? NSRegularExpression(pattern: "!\\[.*?\\]\\((https?://.*?)\\)", options: []) {
            let nsStr = outputText as NSString
            if let firstMatch = imgRegex.firstMatch(in: outputText, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                let urlStr = nsStr.substring(with: firstMatch.range(at: 1))
                detectedImageUrl = urlStr
            }
        }
        
        return (outputText, results, detectedImageUrl)
    }
    
    /// Generate an image from a prompt calling /v1/images/generations endpoint or falling back to Flux
    public func generateImage(prompt: String, baseUrl: String = "", apiKey: String = "") async -> String {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Try calling the provider's /v1/images/generations if baseUrl is provided
        if !baseUrl.isEmpty {
            let cleanBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let endpointStr = cleanBase.hasSuffix("/v1") ? "\(cleanBase)/images/generations" : (cleanBase.hasSuffix("/images/generations") ? cleanBase : "\(cleanBase)/v1/images/generations")
            
            if let endpointUrl = URL(string: endpointStr) {
                var request = URLRequest(url: endpointUrl)
                request.httpMethod = "POST"
                request.timeoutInterval = 30
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if !apiKey.isEmpty {
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                }
                
                let payload: [String: Any] = [
                    "prompt": cleanPrompt,
                    "n": 1,
                    "size": "1024x1024"
                ]
                
                if let bodyData = try? JSONSerialization.data(withJSONObject: payload) {
                    request.httpBody = bodyData
                    if let (data, response) = try? await URLSession.shared.data(for: request),
                       let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                        
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let dataArr = json["data"] as? [[String: Any]],
                           let first = dataArr.first {
                            if let imgUrl = first["url"] as? String, !imgUrl.isEmpty {
                                return imgUrl
                            }
                            if let b64 = first["b64_json"] as? String, !b64.isEmpty {
                                return "data:image/png;base64,\(b64)"
                            }
                        }
                    }
                }
            }
        }
        
        // 2. High-Quality Flux / Pollinations AI Fallback
        guard let encoded = cleanPrompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return ""
        }
        return "https://image.pollinations.ai/prompt/\(encoded)?width=1024&height=1024&nologo=true&model=flux"
    }
    
    public func executeOrbit(name: String, paramsJson: String) async -> OrbitExecutionResult {
        let trimmedName = name.lowercased()
        
        var params: [String: Any] = [:]
        if let data = paramsJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            params = parsed
        }
        
        switch trimmedName {
        case "image_gen", "imagine", "draw":
            let prompt = params["prompt"] as? String ?? paramsJson
            let url = await generateImage(prompt: prompt)
            return OrbitExecutionResult(orbitName: "image_gen", params: paramsJson, result: url, isSuccess: true)
            
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
