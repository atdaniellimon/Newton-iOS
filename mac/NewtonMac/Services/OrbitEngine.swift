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
        if outputText.contains("URL: http") || outputText.contains("Citation ID:") || (outputText.contains("Found ") && outputText.contains("results")) {
            let searchDumpPattern = "(?s)(?:Found \\d+ results|URL:\\s*https?://).*?(?=\\n\\n[A-Z¿¡]|$)"
            if let dumpRegex = try? NSRegularExpression(pattern: searchDumpPattern, options: [.caseInsensitive]) {
                let nsOut = outputText as NSString
                let matches = dumpRegex.matches(in: outputText, options: [], range: NSRange(location: 0, length: nsOut.length))
                for match in matches {
                    let dumpText = nsOut.substring(with: match.range(at: 0))
                    results.append(OrbitExecutionResult(orbitName: "web_search", params: "", result: dumpText, isSuccess: true))
                    outputText = outputText.replacingOccurrences(of: dumpText, with: "")
                }
            }
        }
        
        // Clean up remaining raw search scrape artifacts
        if let scrapeRegex = try? NSRegularExpression(pattern: "(?m)^(?:URL:|Last Updated:|title:|keywords:|description:|\\[Publicidad\\]).*$", options: [.caseInsensitive]) {
            outputText = scrapeRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        
        // Clean up remaining raw citation IDs
        if let citRegex = try? NSRegularExpression(pattern: "\\[?Citation ID:\\s*([a-zA-Z0-9_-]+)\\]?", options: [.caseInsensitive]) {
            outputText = citRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        
        // Clean up artificial [CONFIDENCE: ...] and [PREMISE] -> [LOGIC] -> [CONCLUSION] boilerplate
        if let confRegex = try? NSRegularExpression(pattern: "\\[CONFIDENCE:\\s*\\w+\\]\\s*[-—:]?\\s*", options: [.caseInsensitive]) {
            outputText = confRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        if let logicRegex = try? NSRegularExpression(pattern: "\\[PREMISE\\]\\s*→\\s*\\[LOGIC\\]\\s*→\\s*\\[CONCLUSION\\]", options: [.caseInsensitive]) {
            outputText = logicRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        
        // Clean up repetitive identity clauses if present
        outputText = outputText.replacingOccurrences(of: ", de la familia de modelos Newton", with: "")
        outputText = outputText.replacingOccurrences(of: ", from the Newton model family", with: "")
        
        // Strip markdown image syntax and repetitive Generated Image labels from text
        if let mdImgRegex = try? NSRegularExpression(pattern: "!\\[.*?\\]\\(.*?\\)", options: []) {
            outputText = mdImgRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        if let genImgRegex = try? NSRegularExpression(pattern: "(?im)^\\s*(?:Generated Image|Imagen generada)\\s*$", options: []) {
            outputText = genImgRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        
        // 4. Fallback: Intent matching from user prompt (EXPLICIT image requests only)
        if detectedImageUrl == nil && !userPrompt.isEmpty {
            let lower = userPrompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isCapabilityQuestion = lower.contains("que puedes hacer") || lower.contains("qué puedes hacer") || lower.contains("que sabes hacer") || lower.contains("qué sabes hacer") || lower.contains("quien eres") || lower.contains("quién eres") || lower.hasPrefix("hola")
            
            if !isCapabilityQuestion {
                let imgIntentPattern = "(?i)(?:^/imagine\\s+(.+)|(?:dibuja[rs]?|dib[uú]jame|pinta[rs]?|pintame|ilustra[rs]?|renderiza[rs]?|draw|paint|illustrate)\\s+(?:una?\\s+|an?\\s+)?(.+)|(?:(?:me\\s+)?(?:puedes\\s+)?(?:hacer|hazme|haz|genera[rs]?|gener[aá]me|crea[rs]?|cre[aá]me|make|generate|create)\\s+(?:me|nos)?\\s*(?:una?\\s+|an?\\s+)(?:imagen|foto|dibujo|gr[aá]fico|ilustraci[oó]n|image|photo|picture|drawing|artwork|render)\\s*(?:de|sobre|para|of|about|for)?\\s*(.+)))"
                
                if let intentRegex = try? NSRegularExpression(pattern: imgIntentPattern, options: []) {
                    let nsPrompt = userPrompt as NSString
                    if let match = intentRegex.firstMatch(in: userPrompt, options: [], range: NSRange(location: 0, length: nsPrompt.length)) {
                        var subject = ""
                        for idx in 1..<match.numberOfRanges {
                            if match.range(at: idx).location != NSNotFound {
                                subject = nsPrompt.substring(with: match.range(at: idx))
                                break
                            }
                        }
                        
                        let cleanSubj = subject.trimmingCharacters(in: CharacterSet(charactersIn: "?!., \t\n"))
                        if !cleanSubj.isEmpty {
                            detectedImageUrl = await generateImage(prompt: cleanSubj, baseUrl: baseUrl, apiKey: apiKey)
                            if outputText.isEmpty || outputText.contains("No pude generar") || outputText.contains("no puedo generar") || outputText.contains("no tengo la capacidad") || outputText.contains("Parece que no puedo") {
                                outputText = "¡Claro que sí! Aquí tienes una imagen de **\(cleanSubj)**:"
                            }
                        }
                    }
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
    
    /// Generate an image from a prompt calling ONLY the official API endpoint
    public func generateImage(prompt: String, baseUrl: String = "", apiKey: String = "") async -> String {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetBase = !baseUrl.isEmpty ? baseUrl : SettingsManager.hardcodedEndpoint
        let cleanBase = targetBase.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointStr = cleanBase.hasSuffix("/v1") ? "\(cleanBase)/images/generations" : (cleanBase.hasSuffix("/images/generations") ? cleanBase : "\(cleanBase)/v1/images/generations")
        
        guard let endpointUrl = URL(string: endpointStr) else { return "" }
        
        var request = URLRequest(url: endpointUrl)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let payload: [String: Any] = [
            "prompt": cleanPrompt,
            "n": 1,
            "size": "1024x1024",
            "response_format": "b64_json"
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return "" }
        request.httpBody = bodyData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                return ""
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArr = json["data"] as? [[String: Any]],
               let first = dataArr.first {
                if let b64 = first["b64_json"] as? String, !b64.isEmpty {
                    return "data:image/png;base64,\(b64)"
                }
                if let imgUrl = first["url"] as? String, !imgUrl.isEmpty {
                    return imgUrl
                }
            }
        } catch {
            print("Official Image API error: \(error)")
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
            
        case "read_file", "view_file":
            let path = params["path"] as? String ?? paramsJson.trimmingCharacters(in: .whitespacesAndNewlines)
            let (content, error) = NewtonCodeWorkspaceManager.shared.readFile(relativePath: path)
            if let error = error {
                return OrbitExecutionResult(orbitName: "read_file", params: path, result: "Error: \(error)", isSuccess: false)
            }
            return OrbitExecutionResult(orbitName: "read_file", params: path, result: content, isSuccess: true)
            
        case "write_file", "create_file":
            let path = params["path"] as? String ?? ""
            let content = params["content"] as? String ?? ""
            let (success, error) = NewtonCodeWorkspaceManager.shared.writeFile(relativePath: path, content: content)
            return OrbitExecutionResult(orbitName: "write_file", params: path, result: success ? "File saved successfully" : (error ?? "Failed"), isSuccess: success)
            
        case "edit_file", "replace_file_content":
            let path = params["path"] as? String ?? ""
            let target = params["target"] as? String ?? ""
            let replacement = params["replacement"] as? String ?? ""
            let (success, error) = NewtonCodeWorkspaceManager.shared.editFile(relativePath: path, target: target, replacement: replacement)
            return OrbitExecutionResult(orbitName: "edit_file", params: path, result: success ? "File edited successfully" : (error ?? "Failed"), isSuccess: success)
            
        case "delete_file", "remove_file":
            let path = params["path"] as? String ?? paramsJson.trimmingCharacters(in: .whitespacesAndNewlines)
            let (success, error) = NewtonCodeWorkspaceManager.shared.deleteFile(relativePath: path)
            return OrbitExecutionResult(orbitName: "delete_file", params: path, result: success ? "File deleted" : (error ?? "Failed"), isSuccess: success)
            
        case "run_command", "bash", "terminal":
            let cmd = params["command"] as? String ?? paramsJson.trimmingCharacters(in: .whitespacesAndNewlines)
            let (output, exitCode) = await NewtonCodeWorkspaceManager.shared.runBashCommand(command: cmd)
            return OrbitExecutionResult(orbitName: "run_command", params: cmd, result: output, isSuccess: exitCode == 0)
            
        case "kick", "terminate":
            var reason = "Operational boundary violations or systematic refusal."
            if let data = paramsJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let r = json["reason"] as? String, !r.isEmpty {
                reason = r
            }
            return OrbitExecutionResult(orbitName: "kick", params: paramsJson, result: reason, isSuccess: true)
            
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
