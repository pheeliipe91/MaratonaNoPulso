import Foundation
import Combine

class AIService: ObservableObject {
    
    private let openAIAPIKey = "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"
    
    // MARK: - Treino Avulso (VoiceCoachView)
    func generateWorkoutPlan(from userMessage: String) async -> AIWorkoutPlan? {
        let systemPrompt = """
        Retorne APENAS JSON válido para um treino de corrida.
        Exemplo:
        {
          "workout_type": "outdoor_run",
          "duration_minutes": 30,
          "distance_km": 5.0,
          "pace_min_per_km": 6.0,
          "segments": [
            {"type": "warmup", "duration_minutes": 5},
            {"type": "main", "duration_minutes": 20},
            {"type": "cooldown", "duration_minutes": 5}
          ]
        }
        """
        
        return await makeRequest(prompt: systemPrompt, userMessage: userMessage, responseType: AIWorkoutPlan.self)
    }
    
    // MARK: - Plano Semanal (WeeklyPlanView)
    func generateWeeklyPlan(from userMessage: String) async -> WeeklyTrainingPlan? {
        let systemPrompt = """
        Retorne APENAS JSON válido para um plano semanal.
        Estrutura: { "plan_name": "Nome", "workouts": [ ... ] }
        Use "workout_type": "outdoor_run", "rest", "walk".
        """
        return await makeRequest(prompt: systemPrompt, userMessage: userMessage, responseType: WeeklyTrainingPlan.self)
    }
    
    // Helper Genérico
    private func makeRequest<T: Decodable>(prompt: String, userMessage: String, responseType: T.Type) async -> T? {
        do {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
            
            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": prompt],
                    ["role": "user", "content": userMessage]
                ],
                "temperature": 0.3
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let content = choices.first?["message"] as? [String: Any]? ?? [:],
               let text = content["content"] as? String {
                
                let cleanedText = cleanJSONString(text)
                if let jsonData = cleanedText.data(using: .utf8) {
                    return try JSONDecoder().decode(T.self, from: jsonData)
                }
            }
        } catch {
            print("❌ Erro AI: \(error)")
        }
        return nil
    }
    
    private func cleanJSONString(_ input: String) -> String {
        var text = input
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        return text
    }
}
