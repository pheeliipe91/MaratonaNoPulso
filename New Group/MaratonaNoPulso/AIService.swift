import Foundation
import Combine

class AIService: ObservableObject {
    
    private let openAIAPIKey: String

    init() {
        // Vamos simplificar a API Key primeiro
        self.openAIAPIKey = "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"
    }
    
    func generateWorkoutPlan(from userMessage: String) async -> WorkoutPlan? {
        let systemPrompt = """
        Você é um coach especialista em corrida. Analise a solicitação e retorne APENAS JSON ou uma pergunta.

        EXEMPLO DE RESPOSTA JSON:
        {
          "workout_type": "running",
          "duration_minutes": 30,
          "distance_km": 5.0,
          "pace_min_per_km": 6.0
        }

        EXEMPLO DE PERGUNTA:
        "Para qual distância você quer treinar: 5km, 10km ou meia-maratona?"
        """
        
        print("🚀 DEBUG: Enviando para ChatGPT: '\(userMessage)'")
        
        do {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
            
            let requestBody: [String: Any] = [
                "model": "gpt-3.5-turbo", // Mais rápido e barato para teste
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userMessage]
                ],
                "max_tokens": 500,
                "temperature": 0.3
            ]
            
            print("🔧 DEBUG: Request Body: \(requestBody)")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // DEBUG da resposta
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 DEBUG: Status Code: \(httpResponse.statusCode)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "No response"
            print("📨 DEBUG: Resposta bruta: \(responseString)")
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if let error = json["error"] as? [String: Any] {
                    print("❌ DEBUG: Erro da API: \(error)")
                    return nil
                }
                
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    print("✅ DEBUG: Conteúdo recebido: '\(content)'")
                    
                    // Tenta parsear como JSON
                    if let jsonData = content.data(using: .utf8),
                       let workoutPlan = try? JSONDecoder().decode(WorkoutPlan.self, from: jsonData) {
                        print("🎯 DEBUG: JSON parseado com sucesso!")
                        return workoutPlan
                    } else {
                        // Se não for JSON, é uma pergunta
                        print("❓ DEBUG: ChatGPT fez uma pergunta")
                        return WorkoutPlan(needsMoreInfo: content)
                    }
                }
            }
            
        } catch {
            print("💥 DEBUG: ERRO na requisição: \(error.localizedDescription)")
        }
        
        return nil
    }
}
