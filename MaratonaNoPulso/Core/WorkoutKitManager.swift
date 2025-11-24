import Foundation
import WorkoutKit
import HealthKit

// Certifique-se de importar Models se estiverem em outro módulo,
// ou que WorkoutPlan esteja acessível aqui.

class WorkoutKitManager: ObservableObject {
    
    static let shared = WorkoutKitManager()
    
    private init() {}
    
    /// Transforma o plano da AI em um CustomWorkout do iOS 17+
    /// Retorna um CustomWorkout pronto para ser apresentado via .workoutPreview
    func createCustomWorkout(from plan: WorkoutPlan) -> CustomWorkout? {
        
        // 1. Converter segmentos (Warmup, Main, Cooldown) em IntervalSteps
        var steps: [IntervalStep] = []
        
        if let segments = plan.segments {
            for segment in segments {
                let step = createStep(from: segment)
                steps.append(step)
            }
        } else {
            // Fallback se não houver segmentos: cria um treino simples
            let mainGoal = convertToGoal(duration: plan.duration_minutes)
            steps.append(IntervalStep(purpose: .work, goal: mainGoal))
        }
        
        // 2. Criar o Bloco de Intervalo (Obrigatório no WorkoutKit)
        // Iterations = 1 significa que o bloco roda uma vez sequencialmente
        let block = IntervalBlock(steps: steps, iterations: 1)
        
        // 3. Criar o objeto CustomWorkout
        // Este objeto é o que o iOS reconhece nativamente como Template
        let workout = CustomWorkout(
            activity: .running,
            location: .outdoor, // Pode mudar para .indoor se necessário
            displayName: "MaratonaNoPulso: \(plan.workout_type.capitalized)",
            warmup: nil, // Já incluímos o warmup dentro dos steps/blocos para mais controle
            blocks: [block],
            cooldown: nil // Já incluímos no steps
        )
        
        return workout
    }
    
    // MARK: - Helpers Privados
    
    private func createStep(from segment: WorkoutSegment) -> IntervalStep {
        // Definir o propósito (Aquecimento, Trabalho, Desaquecimento)
        let purpose: IntervalStep.Purpose
        switch segment.type.lowercased() {
        case "warmup", "warm-up":
            purpose = .warmup
        case "cooldown", "cool-down":
            purpose = .cooldown
        case "recovery":
            purpose = .recovery
        default:
            purpose = .work
        }
        
        // Definir a meta (Tempo ou Distância)
        // A AI manda duration_minutes. Se for 0, tentamos distância (lógica futura)
        let goal: WorkoutGoal = .time(Double(segment.duration_minutes), .minutes)
        
        // Opcional: Adicionar Alerta de Ritmo (Pace Alert)
        // Se o JSON tiver "pace_min_per_km", podemos adicionar aqui um `WaitGoal` ou `Alert`
        
        return IntervalStep(purpose: purpose, goal: goal)
    }
    
    private func convertToGoal(duration: Int) -> WorkoutGoal {
        return .time(Double(duration), .minutes)
    }
}
