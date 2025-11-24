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
        
        // Código existente continua...
        return nil
    }
    
    // MARK: - Gerar Plano Semanal Completo
    
    func generateWeeklyPlan(from userMessage: String) async -> WeeklyTrainingPlan? {
        let systemPrompt = """
        Você é um coach especialista em corrida. Crie um plano de treino semanal personalizado.
        
        RETORNE APENAS JSON no seguinte formato:
        {
          "plan_name": "Nome do Plano",
          "goal_description": "Descrição do objetivo",
          "total_days": 7,
          "workouts": [
            {
              "day": 1,
              "workout_name": "Corrida Leve - Dia 1",
              "workout_type": "outdoor_run",
              "duration_minutes": 20,
              "distance_km": 2.0,
              "pace_min_per_km": 7.0,
              "is_rest_day": false,
              "instructions": "Comece devagar, mantenha ritmo confortável",
              "segments": [
                {
                  "type": "warmup",
                  "duration_minutes": 5,
                  "intensity": "easy",
                  "description": "Caminhada leve",
                  "target_pace": null
                },
                {
                  "type": "main",
                  "duration_minutes": 10,
                  "intensity": "moderate",
                  "description": "Corrida contínua",
                  "target_pace": 7.0
                },
                {
                  "type": "cooldown",
                  "duration_minutes": 5,
                  "intensity": "easy",
                  "description": "Caminhada para recuperar",
                  "target_pace": null
                }
              ]
            },
            {
              "day": 2,
              "workout_name": "Descanso Ativo",
              "workout_type": "rest",
              "duration_minutes": 0,
              "distance_km": null,
              "pace_min_per_km": null,
              "is_rest_day": true,
              "instructions": "Descanse ou faça alongamento leve",
              "segments": null
            }
          ]
        }
        
        REGRAS:
        - workout_type deve ser: outdoor_run, indoor_run, walk, rest, ou cross_training
        - Inclua dias de descanso
        - Aumente progressivamente a dificuldade
        - Seja realista para iniciantes
        - Retorne SOMENTE o JSON, nada mais
        
        Se precisar de mais informações, retorne apenas uma pergunta em texto simples.
        """
        
        print("🚀 DEBUG: Gerando plano semanal para: '\(userMessage)'")
        
        do {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
            
            let requestBody: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userMessage]
                ],
                "max_tokens": 2000,
                "temperature": 0.3
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 DEBUG: Status Code: \(httpResponse.statusCode)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "No response"
            print("📨 DEBUG: Resposta bruta: \(responseString.prefix(500))")
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if let error = json["error"] as? [String: Any] {
                    print("❌ DEBUG: Erro da API: \(error)")
                    return nil
                }
                
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    print("✅ DEBUG: Conteúdo recebido!")
                    
                    // Limpar o conteúdo removendo markdown code blocks
                    let cleanedContent = content
                        .replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Tenta parsear como JSON
                    if let jsonData = cleanedContent.data(using: .utf8),
                       let weeklyPlan = try? JSONDecoder().decode(WeeklyTrainingPlan.self, from: jsonData) {
                        print("🎯 DEBUG: Plano semanal parseado com sucesso!")
                        print("📋 Total de treinos: \(weeklyPlan.workouts.count)")
                        return weeklyPlan
                    } else {
                        // Se não for JSON, é uma pergunta
                        print("❓ DEBUG: ChatGPT fez uma pergunta")
                        return WeeklyTrainingPlan(needsMoreInfo: cleanedContent)
                    }
                }
            }
            
        } catch {
            print("💥 DEBUG: ERRO na requisição: \(error.localizedDescription)")
        }
        
        return nil
    }
}
