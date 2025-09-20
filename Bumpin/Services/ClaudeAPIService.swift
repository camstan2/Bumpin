import Foundation

class ClaudeAPIService {
    static let shared = ClaudeAPIService()
    
    enum ClaudeError: Error {
        case invalidResponse
        case apiError(String)
        case parsingError
        case networkError
    }
    
    func callClaude(prompt: String) async throws -> String {
        let endpoint = AppConfig.API.claudeAPIBaseURL.appendingPathComponent("messages")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("anthropic-version-2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("Bearer \(AppConfig.API.claudeAPIKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "claude-3-sonnet-20240229",
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw ClaudeError.parsingError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ClaudeError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                throw ClaudeError.parsingError
            }
            
            return text
        } catch let error as ClaudeError {
            throw error
        } catch {
            throw ClaudeError.networkError
        }
    }
    
    func callClaudeWithStreaming(prompt: String, onChunk: @escaping (String) -> Void) async throws {
        let endpoint = AppConfig.API.claudeAPIBaseURL.appendingPathComponent("messages")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("anthropic-version-2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("Bearer \(AppConfig.API.claudeAPIKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "claude-3-sonnet-20240229",
            "max_tokens": 1000,
            "stream": true,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw ClaudeError.parsingError
        }
        
        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw ClaudeError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            for try await line in asyncBytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    if jsonString == "[DONE]" {
                        break
                    }
                    
                    guard let data = jsonString.data(using: String.Encoding.utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let delta = json["delta"] as? [String: Any],
                          let text = delta["text"] as? String else {
                        continue
                    }
                    
                    onChunk(text)
                }
            }
        } catch let error as ClaudeError {
            throw error
        } catch {
            throw ClaudeError.networkError
        }
    }
}
