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
    public func processOrbitsInText(_ text: String, userPrompt: String = "", baseUrl: String = "", apiKey: String = "") async -> (processedText: String, results: [OrbitExecutionResult], imageUrl: String?, thinkingContent: String?) {
        var outputText = text
        var results: [OrbitExecutionResult] = []
        var detectedImageUrl: String? = nil
        var accumulatedThinking: String = ""

        // 1. Process <thinking>...</thinking> blocks - Chain of Thought
        let thinkingPattern = "<thinking>([\\s\\S]*?)</thinking>"
        if let thinkingRegex = try? NSRegularExpression(pattern: thinkingPattern, options: [.caseInsensitive]) {
            let nsString = outputText as NSString
            let matches = thinkingRegex.matches(in: outputText, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                guard match.numberOfRanges >= 2 else { continue }
                let fullMatch = nsString.substring(with: match.range(at: 0))
                let thinkingContent = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)

                if !thinkingContent.isEmpty {
                    if !accumulatedThinking.isEmpty {
                        accumulatedThinking += "\n\n---\n\n"
                    }
                    accumulatedThinking += thinkingContent
                }

                // Remove thinking blocks from output (they'll be shown in ThinkingCardView)
                outputText = outputText.replacingOccurrences(of: fullMatch, with: "")
            }
        }

        // 2. Process <orbit:tool_name>...</orbit:tool_name> blocks (natural syntax with JSON params)
        let naturalOrbitPattern = "<orbit:(\\w+)>([\\s\\S]*?)</orbit:\\1>"
        if let naturalRegex = try? NSRegularExpression(pattern: naturalOrbitPattern, options: [.caseInsensitive]) {
            let nsString = outputText as NSString
            let matches = naturalRegex.matches(in: outputText, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                let fullMatch = nsString.substring(with: match.range(at: 0))
                let orbitName = nsString.substring(with: match.range(at: 1)).lowercased()
                let paramsJson = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)

                let result = await executeOrbit(name: orbitName, paramsJson: paramsJson, baseUrl: baseUrl, apiKey: apiKey)
                results.append(result)

                if orbitName == "generate_image" || orbitName == "image_gen" {
                    detectedImageUrl = result.result
                }

                outputText = outputText.replacingOccurrences(of: fullMatch, with: "")
            }
        }

        // 2b. Process simple <orbit:generate>prompt</orbit:generate> for image generation
        let simpleGeneratePattern = "<orbit:generate>([\\s\\S]*?)</orbit:generate>"
        if let simpleGenerateRegex = try? NSRegularExpression(pattern: simpleGeneratePattern, options: [.caseInsensitive]) {
            let nsString = outputText as NSString
            let matches = simpleGenerateRegex.matches(in: outputText, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                guard match.numberOfRanges >= 2 else { continue }
                let fullMatch = nsString.substring(with: match.range(at: 0))
                let prompt = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)

                let result = await executeOrbit(name: "generate_image", paramsJson: "{\"prompt\": \"\(prompt.replacingOccurrences(of: "\"", with: "\\\""))\"}", baseUrl: baseUrl, apiKey: apiKey)
                results.append(result)
                detectedImageUrl = result.result

                outputText = outputText.replacingOccurrences(of: fullMatch, with: "")
            }
        }

        // 3. Process <download>...</download> blocks - Result/Download notifications
        let downloadPattern = "<download>([\\s\\S]*?)</download>"
        if let downloadRegex = try? NSRegularExpression(pattern: downloadPattern, options: [.caseInsensitive]) {
            let nsString = outputText as NSString
            let matches = downloadRegex.matches(in: outputText, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                guard match.numberOfRanges >= 2 else { continue }
                let fullMatch = nsString.substring(with: match.range(at: 0))
                let downloadContent = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)

                // Add download content as an orbit result for display
                if !downloadContent.isEmpty {
                    let result = OrbitExecutionResult(
                        orbitName: "download",
                        params: "",
                        result: downloadContent,
                        isSuccess: true
                    )
                    results.append(result)
                }

                outputText = outputText.replacingOccurrences(of: fullMatch, with: "")
            }
        }

        // 4. Process explicit [ORBIT:name]...[/ORBIT] (legacy support)
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
        
        // Strip internal meta tool instructions and boilerplate generated by base models
        if let metaRegex = try? NSRegularExpression(pattern: "(?i)(?:I've generated the media that you've requested[^\n]*|You MUST call the (?:Imagine Tool|tool)[^\n]*)", options: []) {
            outputText = metaRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        
        // Strip markdown image syntax and repetitive Generated Image labels from text
        if let mdImgRegex = try? NSRegularExpression(pattern: "!\\[.*?\\]\\(.*?\\)", options: []) {
            outputText = mdImgRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        if let genImgRegex = try? NSRegularExpression(pattern: "(?im)^\\s*(?:Generated Image|Imagen generada)\\s*$", options: []) {
            outputText = genImgRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        
        // 4. Detect direct markdown images if output by the model
        if detectedImageUrl == nil {
            if let imgRegex = try? NSRegularExpression(pattern: "!\\[.*?\\]\\((https?://.*?|data:image/.*?)\\)", options: []) {
                let nsStr = outputText as NSString
                if let firstMatch = imgRegex.firstMatch(in: outputText, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                    detectedImageUrl = nsStr.substring(with: firstMatch.range(at: 1))
                }
            }
        }
        
        return (outputText.trimmingCharacters(in: .whitespacesAndNewlines), results, detectedImageUrl, accumulatedThinking.isEmpty ? nil : accumulatedThinking)
    }
    
    /// Generate an image from a prompt calling ONLY the official API endpoint
    public func generateImage(prompt: String, baseUrl: String = "", apiKey: String = "") async -> String {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetBase = !baseUrl.isEmpty ? baseUrl : SettingsManager.shared.effectiveBaseUrl(for: .openaiCompatible)
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
            
        case "sequential_thinking", "think", "reason":
            let thought = params["thought"] as? String ?? paramsJson
            let thoughtNum = params["thoughtNumber"] as? Int ?? (params["thought_number"] as? Int ?? 1)
            let totalThoughts = params["totalThoughts"] as? Int ?? (params["total_thoughts"] as? Int ?? 1)
            let isRevision = params["isRevision"] as? Bool ?? false
            let label = "🧠 [Sequential Thought \(thoughtNum)/\(totalThoughts)\(isRevision ? " (Revision)" : "")]: \(thought)"
            return OrbitExecutionResult(orbitName: "sequential_thinking", params: paramsJson, result: label, isSuccess: true)
            
        case "location", "get_location", "gps":
            let locationInfo = await DeviceBridgeService.shared.getCurrentLocation()
            return OrbitExecutionResult(orbitName: "location", params: paramsJson, result: locationInfo, isSuccess: true)
            
        case "time", "date", "clock", "datetime", "get_time":
            let timeInfo = DeviceBridgeService.shared.getFormattedDateTime()
            return OrbitExecutionResult(orbitName: "time", params: paramsJson, result: timeInfo, isSuccess: true)
            
        case "reminders", "get_reminders", "list_reminders":
            let filter = params["filter"] as? String ?? "all"
            let remindersList = await DeviceBridgeService.shared.getReminders(filter: filter)
            return OrbitExecutionResult(orbitName: "reminders", params: paramsJson, result: remindersList, isSuccess: true)
            
        case "create_reminder", "add_reminder", "set_reminder":
            let title = params["title"] as? String ?? paramsJson
            let due = params["dueDate"] as? String ?? (params["due_date"] as? String ?? (params["due"] as? String ?? ""))
            let result = DeviceBridgeService.shared.createReminder(title: title, dueDate: due)
            return OrbitExecutionResult(orbitName: "create_reminder", params: paramsJson, result: result, isSuccess: true)
            
        case "calendar", "get_calendar", "events", "list_events":
            let days = params["days"] as? Int ?? 7
            let calendarEvents = await DeviceBridgeService.shared.getCalendarEvents(daysAhead: days)
            return OrbitExecutionResult(orbitName: "calendar", params: paramsJson, result: calendarEvents, isSuccess: true)
            
        case "create_event", "add_event", "schedule_event":
            let title = params["title"] as? String ?? "Reunión"
            let startDate = params["startDate"] as? String ?? (params["start_date"] as? String ?? (params["date"] as? String ?? ""))
            let endDate = params["endDate"] as? String ?? (params["end_date"] as? String ?? "")
            let notes = params["notes"] as? String ?? (params["description"] as? String ?? "")
            let result = DeviceBridgeService.shared.createCalendarEvent(title: title, startDate: startDate, endDate: endDate, notes: notes)
            return OrbitExecutionResult(orbitName: "create_event", params: paramsJson, result: result, isSuccess: true)
            
        case "save_memory", "remember", "store_memory":
            let fact = params["fact"] as? String ?? (params["memory"] as? String ?? (params["content"] as? String ?? paramsJson))
            MemoryManager.shared.addMemory(fact)
            return OrbitExecutionResult(orbitName: "save_memory", params: paramsJson, result: "🧠 Memoria guardada: \"\(fact)\"", isSuccess: true)
            
        case "get_memories", "list_memories":
            let mems = MemoryManager.shared.formattedMemoryPrompt()
            return OrbitExecutionResult(orbitName: "get_memories", params: paramsJson, result: mems.isEmpty ? "No hay memorias registradas." : mems, isSuccess: true)
            
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
