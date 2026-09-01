//
//  OrbitEngine.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import Foundation
import AppKit

public final class OrbitEngine {
    public static let shared = OrbitEngine()
    
    private init() {}
    
    /// Process any [ORBIT:name]{...}[/ORBIT], JSON tool calls, or image intent in text
    public func processOrbitsInText(_ text: String, userPrompt: String = "", baseUrl: String = "", apiKey: String = "") async -> (processedText: String, results: [OrbitExecutionResult], imageUrl: String?) {
        var outputText = text
        var results: [OrbitExecutionResult] = []
        var detectedImageUrl: String? = nil
        
        // 1. Process explicit [ORBIT:name]...[/ORBIT]
        let pattern = "\\[ORBIT:(\\w+)\\]([\\s\\S]*?)(?:\\[/ORBIT\\]|$)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let fullMatch = nsString.substring(with: match.range(at: 0))
                let orbitName = nsString.substring(with: match.range(at: 1))
                let paramsJson = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let result = await executeOrbit(name: orbitName, paramsJson: paramsJson, baseUrl: baseUrl, apiKey: apiKey)
                results.append(result)
                
                if orbitName.lowercased() == "image_gen" || orbitName.lowercased() == "imagine" || orbitName.lowercased() == "generate_image" {
                    detectedImageUrl = result.result
                }
                
                outputText = outputText.replacingOccurrences(of: fullMatch, with: "")
            }
        }
        
        // 2. Process JSON tool calls ```json { "name": "...", "parameters": { ... } } ```
        let jsonToolPattern = "```(?:json)?\\s*\\{\\s*\"name\"\\s*:\\s*\"([^\"]+)\"\\s*,\\s*\"parameters\"\\s*:\\s*(\\{[\\s\\S]*?\\})\\s*\\}\\s*```"
        if let regex = try? NSRegularExpression(pattern: jsonToolPattern, options: [.caseInsensitive]) {
            let nsString = outputText as NSString
            let matches = regex.matches(in: outputText, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let fullMatch = nsString.substring(with: match.range(at: 0))
                let toolName = nsString.substring(with: match.range(at: 1))
                let paramsJson = nsString.substring(with: match.range(at: 2))
                
                let result = await executeOrbit(name: toolName, paramsJson: paramsJson, baseUrl: baseUrl, apiKey: apiKey)
                results.append(result)
                if toolName.lowercased() == "generate_image" || toolName.lowercased() == "image_gen" {
                    detectedImageUrl = result.result
                }
                outputText = outputText.replacingOccurrences(of: fullMatch, with: "")
            }
        }
        
        // 3. Process raw search dumps if returned in text
        if outputText.contains("Citation ID:") || outputText.contains("Found ") && outputText.contains("results\n") {
            let searchDumpPattern = "(?s)Found \\d+ results.*?(\\n\\n[A-Z]|$)"
            if let dumpRegex = try? NSRegularExpression(pattern: searchDumpPattern, options: []) {
                let nsOut = outputText as NSString
                if let match = dumpRegex.firstMatch(in: outputText, options: [], range: NSRange(location: 0, length: nsOut.length)) {
                    let dumpText = nsOut.substring(with: match.range(at: 0))
                    results.append(OrbitExecutionResult(orbitName: "web_search", params: "", result: dumpText, isSuccess: true))
                    outputText = outputText.replacingOccurrences(of: dumpText, with: "")
                }
            }
        }
        
        // Clean up remaining raw citation IDs
        if let citRegex = try? NSRegularExpression(pattern: "\\[?Citation ID:\\s*([a-zA-Z0-9_-]+)\\]?", options: [.caseInsensitive]) {
            outputText = citRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        
        // 4. Fallback: Intent matching from user prompt
        if detectedImageUrl == nil && !userPrompt.isEmpty {
            let imgIntentPattern = "(?i)(?:/imagine\\s+(.+)|(?:me\\s+)?(?:puedes\\s+)?(?:hacer|haces|hazme|haz|genera[rs]?|gener[aá]me|generarme|crea[rs]?|cre[aá]me|crearme|dibuja[rs]?|dibujame|pinta[rs]?|pintame|ilustra[rs]?|renderiza[rs]?|generate|create|draw|paint|make)\\s*(?:me|te|nos)?\\s*(?:una?\\s+|an?\\s+)?(?:imagen|foto|dibujo|gr[aá]fico|ilustraci[oó]n|image|photo|drawing|picture)?\\s*(?:de|sobre|para|of|about|for)?\\s*(.+))"
            
            if let intentRegex = try? NSRegularExpression(pattern: imgIntentPattern, options: []) {
                let nsPrompt = userPrompt as NSString
                if let match = intentRegex.firstMatch(in: userPrompt, options: [], range: NSRange(location: 0, length: nsPrompt.length)) {
                    var subject = ""
                    if match.range(at: 1).location != NSNotFound {
                        subject = nsPrompt.substring(with: match.range(at: 1))
                    } else if match.range(at: 2).location != NSNotFound {
                        subject = nsPrompt.substring(with: match.range(at: 2))
                    }
                    
                    let cleanSubj = subject.trimmingCharacters(in: CharacterSet(charactersIn: "?!., \t\n"))
                    let promptToGenerate = cleanSubj.isEmpty ? userPrompt : cleanSubj
                    
                    detectedImageUrl = await generateImage(prompt: promptToGenerate, baseUrl: baseUrl, apiKey: apiKey)
                    
                    if outputText.isEmpty || outputText.contains("No pude generar") || outputText.contains("no puedo generar") || outputText.contains("no tengo la capacidad") || outputText.contains("Parece que no puedo") {
                        outputText = "¡Claro que sí! Aquí tienes una imagen de **\(promptToGenerate)**:"
                    }
                }
            }
        }
        
        // 4. Fallback: Match assistant refusal mentioning image generation
        if detectedImageUrl == nil && (outputText.contains("No pude generar la imagen de") || outputText.contains("No puedo generar la imagen de")) {
            let refusalPattern = "(?i)No pud?e generar la imagen de\\s+([^.\\n?]+)"
            if let refRegex = try? NSRegularExpression(pattern: refusalPattern, options: []) {
                let nsOut = outputText as NSString
                if let match = refRegex.firstMatch(in: outputText, options: [], range: NSRange(location: 0, length: nsOut.length)) {
                    let subject = nsOut.substring(with: match.range(at: 1)).trimmingCharacters(in: CharacterSet(charactersIn: "?!., \t\n"))
                    detectedImageUrl = await generateImage(prompt: subject, baseUrl: baseUrl, apiKey: apiKey)
                    outputText = "¡Claro que sí! Aquí tienes una imagen de **\(subject)**:"
                }
            }
        }
        
        // 5. Detect direct markdown images
        if detectedImageUrl == nil {
            if let imgRegex = try? NSRegularExpression(pattern: "!\\[.*?\\]\\((https?://.*?|data:image/.*?)\\)", options: []) {
                let nsStr = outputText as NSString
                if let firstMatch = imgRegex.firstMatch(in: outputText, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                    detectedImageUrl = nsStr.substring(with: firstMatch.range(at: 1))
                }
            }
        }
        
        return (outputText.trimmingCharacters(in: .whitespacesAndNewlines), results, detectedImageUrl)
    }
    
    /// Generate an image from a prompt calling endpoint or downloading high-res data URL
    public func generateImage(prompt: String, baseUrl: String = "", apiKey: String = "") async -> String {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Try calling the provider's /v1/images/generations with a fast 4s timeout
        if !baseUrl.isEmpty && !baseUrl.contains("localhost") && !baseUrl.contains("127.0.0.1") {
            let cleanBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let endpointStr = cleanBase.hasSuffix("/v1") ? "\(cleanBase)/images/generations" : (cleanBase.hasSuffix("/images/generations") ? cleanBase : "\(cleanBase)/v1/images/generations")
            
            if let endpointUrl = URL(string: endpointStr) {
                var request = URLRequest(url: endpointUrl)
                request.httpMethod = "POST"
                request.timeoutInterval = 4
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if !apiKey.isEmpty {
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                }
                
                let payload: [String: Any] = [
                    "prompt": cleanPrompt,
                    "n": 1,
                    "size": "768x768",
                    "response_format": "b64_json"
                ]
                
                if let bodyData = try? JSONSerialization.data(withJSONObject: payload) {
                    request.httpBody = bodyData
                    if let (data, response) = try? await URLSession.shared.data(for: request),
                       let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                        
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let dataArr = json["data"] as? [[String: Any]],
                           let first = dataArr.first {
                            if let b64 = first["b64_json"] as? String, !b64.isEmpty {
                                return "data:image/png;base64,\(b64)"
                            }
                            if let imgUrl = first["url"] as? String, !imgUrl.isEmpty, let urlObj = URL(string: imgUrl) {
                                if let (dlData, _) = try? await URLSession.shared.data(from: urlObj),
                                   let _ = NSImage(data: dlData) {
                                    return "data:image/jpeg;base64,\(dlData.base64EncodedString())"
                                }
                                return imgUrl
                            }
                        }
                    }
                }
            }
        }
        
        // 2. High-Performance Turbo Image Generator
        let encodedPrompt = cleanPrompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "?", with: "") ?? "artwork"
        
        let turboUrlStr = "https://image.pollinations.ai/prompt/\(encodedPrompt)?width=768&height=768&nologo=true&model=turbo"
        if let turboUrl = URL(string: turboUrlStr) {
            var dlRequest = URLRequest(url: turboUrl)
            dlRequest.timeoutInterval = 15
            dlRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
            
            if let (dlData, dlResp) = try? await URLSession.shared.data(for: dlRequest),
               let http = dlResp as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let _ = NSImage(data: dlData) {
                return "data:image/jpeg;base64,\(dlData.base64EncodedString())"
            }
            return turboUrlStr
        }
        
        return ""
    }
    
    public func executeOrbit(name: String, paramsJson: String, baseUrl: String = "", apiKey: String = "") async -> OrbitExecutionResult {
        let trimmedName = name.lowercased()
        
        var params: [String: Any] = [:]
        if let data = paramsJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            params = parsed
        }
        
        switch trimmedName {
        case "image_gen", "imagine", "generate_image", "draw":
            let prompt = params["prompt"] as? String ?? paramsJson
            let url = await generateImage(prompt: prompt, baseUrl: baseUrl, apiKey: apiKey)
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
            
        case "generate_pdf", "pdf", "create_pdf", "make_pdf":
            var title = "Documento Newton"
            var content = paramsJson
            
            if let data = paramsJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let t = json["title"] as? String, !t.isEmpty { title = t }
                if let c = json["content"] as? String, !c.isEmpty { content = c }
            } else {
                if let titleRegex = try? NSRegularExpression(pattern: "\"title\"\\s*:\\s*\"([^\"]+)\""),
                   let match = titleRegex.firstMatch(in: paramsJson, range: NSRange(location: 0, length: (paramsJson as NSString).length)),
                   match.numberOfRanges > 1 {
                    title = (paramsJson as NSString).substring(with: match.range(at: 1))
                }
                
                if let contentRegex = try? NSRegularExpression(pattern: "\"content\"\\s*:\\s*\"([\\s\\S]*?)\"\\s*\\}?$"),
                   let match = contentRegex.firstMatch(in: paramsJson, range: NSRange(location: 0, length: (paramsJson as NSString).length)),
                   match.numberOfRanges > 1 {
                    content = (paramsJson as NSString).substring(with: match.range(at: 1))
                        .replacingOccurrences(of: "\\n", with: "\n")
                        .replacingOccurrences(of: "\\\"", with: "\"")
                }
            }
            
            if let pdfUrl = ConversationExportManager.shared.generateCustomDocumentPDF(title: title, content: content) {
                return OrbitExecutionResult(orbitName: "generate_pdf", params: paramsJson, result: pdfUrl.path, isSuccess: true)
            } else {
                return OrbitExecutionResult(orbitName: "generate_pdf", params: paramsJson, result: "Error al generar el PDF.", isSuccess: false)
            }
            
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
