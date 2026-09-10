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
    
    /// Process any [ORBIT:name]{...}[/ORBIT], JSON tool calls, or image intent in text
    public func processOrbitsInText(_ text: String, userPrompt: String = "", baseUrl: String = "", apiKey: String = "") async -> (processedText: String, results: [OrbitExecutionResult], imageUrl: String?, thinkingContent: String?) {
        var outputText = text
        var results: [OrbitExecutionResult] = []
        var detectedImageUrl: String? = nil
        var accumulatedThinking: String = ""

        // 0. Prioridad 1: Detectar si el modelo ya incluyó una imagen Markdown o URL directa de Meta AI
        if let imgRegex = try? NSRegularExpression(pattern: "!\\[.*?\\]\\((https?://.*?|data:image/.*?)\\)", options: []) {
            let nsStr = outputText as NSString
            if let firstMatch = imgRegex.firstMatch(in: outputText, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                detectedImageUrl = nsStr.substring(with: firstMatch.range(at: 1))
            }
        }

        if detectedImageUrl == nil {
            if let scontentRegex = try? NSRegularExpression(pattern: "(https://[a-zA-Z0-9.-]+\\.fbcdn\\.net/[^\\s\"'<>\n\r\t]+)", options: []) {
                let nsStr = outputText as NSString
                if let firstMatch = scontentRegex.firstMatch(in: outputText, options: [], range: NSRange(location: 0, length: nsStr.length)) {
                    detectedImageUrl = nsStr.substring(with: firstMatch.range(at: 1))
                }
            }
        }

        // 1. Process <thinking>...</thinking> blocks - Chain of Thought (also legacy <think>)
        let thinkingPattern = "<think(?:ing)?>([\\s\\S]*?)</think(?:ing)?>"
        if let thinkingRegex = try? NSRegularExpression(pattern: thinkingPattern, options: [.caseInsensitive]) {
            let nsString = outputText as NSString
            let matches = thinkingRegex.matches(in: outputText, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                guard match.numberOfRanges >= 2 else { continue }
                let fullMatch = nsString.substring(with: match.range(at: 0))
                let thinkingContent = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)

                if !thinkingContent.isEmpty {
                    // Prepend: we iterate matches.reversed(), so this preserves document order.
                    accumulatedThinking = thinkingContent + (accumulatedThinking.isEmpty ? "" : "\n\n---\n\n" + accumulatedThinking)
                }

                // Remove thinking blocks from output (they'll be shown in ThinkingCardView)
                outputText = outputText.replacingOccurrences(of: fullMatch, with: "")
            }
        }

        // 1b. Recover unclosed trailing <thinking> (truncated stream: no closing tag).
        // Extract it into thinking instead of leaving raw text cut off in chat.
        if let openRange = outputText.range(of: "<think", options: [.caseInsensitive]) {
            let tail = String(outputText[openRange.lowerBound...])
            if tail.range(of: "</think", options: [.caseInsensitive]) == nil {
                var thoughtTail = tail
                if let tagEnd = thoughtTail.range(of: ">") {
                    thoughtTail = String(thoughtTail[tagEnd.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !thoughtTail.isEmpty {
                    if !accumulatedThinking.isEmpty {
                        accumulatedThinking += "\n\n---\n\n"
                    }
                    accumulatedThinking += thoughtTail
                }
                outputText = String(outputText[..<openRange.lowerBound])
            }
        }
        // Strip any stray closing think tags left behind
        if let strayClose = try? NSRegularExpression(pattern: "</think(?:ing)?>", options: [.caseInsensitive]) {
            outputText = strayClose.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
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
                    if !result.result.isEmpty {
                        detectedImageUrl = result.result
                    }
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
                if !result.result.isEmpty {
                    detectedImageUrl = result.result
                }

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
                    if !result.result.isEmpty {
                        detectedImageUrl = result.result
                    }
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
                    if !result.result.isEmpty {
                        detectedImageUrl = result.result
                    }
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
                    var dumpText = nsOut.substring(with: match.range(at: 0))
                    // Truncate mega-dumps: cards stay readable, no walls of raw text
                    if dumpText.count > 2000 {
                        dumpText = String(dumpText.prefix(2000)) + "\n\n... (resultado recortado)"
                    }
                    results.append(OrbitExecutionResult(orbitName: "web_search", params: "", result: dumpText, isSuccess: true))
                    outputText = outputText.replacingOccurrences(of: dumpText, with: "")
                }
            }
        }
        
        // Clean up remaining raw search scrape artifacts
        if let scrapeRegex = try? NSRegularExpression(pattern: "(?m)^(?:URL:|Last Updated:|title:|keywords:|description:|\\[Publicidad\\]).*$", options: [.caseInsensitive]) {
            outputText = scrapeRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
        }
        
        // Clean up remaining raw citation IDs: e.g. [Citation ID: f172]
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
        
        // 5. Image-intent fallback: user asked for an image but the model replied
        // in prose (e.g. claimed inability) without emitting any image orbit tag.
        // Detect intent client-side and generate anyway so natural requests work.
        if detectedImageUrl == nil && !results.contains(where: { ["image_gen", "generate_image", "imagine", "draw"].contains($0.orbitName.lowercased()) }) {
            let lowerPrompt = userPrompt.lowercased()
            let imageKeywords = ["genera una imagen", "generame una imagen", "crea una imagen", "haz una imagen", "dibuja", "draw", "generate an image", "create an image", "make an image", "generate a picture", "/imagine"]
            let wantsImage = imageKeywords.contains(where: { lowerPrompt.contains($0) }) || lowerPrompt.hasPrefix("imagine")
            if wantsImage {
                let cleanUserPrompt = userPrompt.replacingOccurrences(of: "\"", with: " ").replacingOccurrences(of: "\n", with: " ")
                let fallback = await executeOrbit(name: "generate_image", paramsJson: "{\"prompt\": \"\(cleanUserPrompt)\"}", baseUrl: baseUrl, apiKey: apiKey)
                results.append(fallback)
                if !fallback.result.isEmpty {
                    detectedImageUrl = fallback.result
                    // Strip refusal prose since the image was actually produced
                    if let refusalRegex = try? NSRegularExpression(pattern: "(?i)(?:no puedo (?:generar|crear)[^\n.]*[\n.]?|lo siento[^\n]*imagen[^\n]*[\n.]?|i can(?:not|'t) (?:generate|create) images?[^\n.]*[\n.]?)", options: []) {
                        outputText = refusalRegex.stringByReplacingMatches(in: outputText, options: [], range: NSRange(location: 0, length: (outputText as NSString).length), withTemplate: "")
                    }
                }
            }
        }

        let finalImageUrl: String? = (detectedImageUrl?.isEmpty == true) ? nil : detectedImageUrl
        return (outputText.trimmingCharacters(in: .whitespacesAndNewlines), results, finalImageUrl, accumulatedThinking.isEmpty ? nil : accumulatedThinking)
    }
    
    /// Generate an image from a prompt calling endpoint or downloading high-res data URL
    public func generateImage(prompt: String, baseUrl: String = "", apiKey: String = "") async -> String {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Determinar la URL del API (soporta servidor local 8765, túnel Cloudflare y custom URL)
        var activeBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeBase.isEmpty {
            activeBase = SettingsManager.shared.effectiveBaseUrl(for: .openaiCompatible).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if activeBase.isEmpty {
            activeBase = "http://127.0.0.1:8765/v1"
        }
        
        let cleanBase = activeBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointStr: String
        if cleanBase.hasSuffix("/v1/images/generations") || cleanBase.hasSuffix("/images/generations") {
            endpointStr = cleanBase
        } else if cleanBase.hasSuffix("/v1") {
            endpointStr = "\(cleanBase)/images/generations"
        } else {
            endpointStr = "\(cleanBase)/v1/images/generations"
        }
        
        // 2. Llamar directamente a tu API /v1/images/generations con 30 segundos de timeout
        if let endpointUrl = URL(string: endpointStr) {
            var request = URLRequest(url: endpointUrl)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let activeKey = apiKey.isEmpty ? SettingsManager.shared.customApiKey : apiKey
            if !activeKey.isEmpty {
                request.setValue("Bearer \(activeKey)", forHTTPHeaderField: "Authorization")
            }
            
            let payload: [String: Any] = [
                "prompt": cleanPrompt,
                "n": 1,
                "size": "1024x1024",
                "model": "dall-e-3"
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
                        if let imgUrl = first["url"] as? String, !imgUrl.isEmpty {
                            return imgUrl
                        }
                    }
                }
            }
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
            
            // 1. Try standard JSON dictionary
            if let data = paramsJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let t = json["title"] as? String, !t.isEmpty { title = t }
                if let c = json["content"] as? String, !c.isEmpty { content = c }
            } else {
                // 2. Regex fallback for JSON with unescaped math / newlines
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
