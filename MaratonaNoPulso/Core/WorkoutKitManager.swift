import Foundation
import WorkoutKit
import HealthKit
import Combine

// MARK: - Extensions
extension UnitFrequency {
    static let beatsPerMinute = UnitFrequency(symbol: "BPM", converter: UnitConverterLinear(coefficient: 1.0 / 60.0))
}

class WorkoutKitManager: ObservableObject {
    
    static let shared = WorkoutKitManager()
    
    private init() {}
    
    // Placeholder estático
    static let emptyPlan: WorkoutKit.WorkoutPlan = {
        let step = IntervalStep(.work, goal: .time(1, .minutes))
        let block = IntervalBlock(steps: [step], iterations: 1)
        let workout = CustomWorkout(activity: .running, location: .outdoor, displayName: "Treino Vazio", warmup: nil, blocks: [block], cooldown: nil)
        return WorkoutKit.WorkoutPlan(.custom(workout))
    }()
    
    func requestAuthorization() async -> Bool { return true }

    // Conversão 1: De DailyPlan
    func createCustomWorkout(from dailyPlan: DailyPlan) async -> CustomWorkout? {
        var segments: [WorkoutSegment]? = nil
        if let structureJson = dailyPlan.structure, let data = structureJson.data(using: .utf8) {
            segments = try? JSONDecoder().decode([WorkoutSegment].self, from: data)
        }
        return await buildCustomWorkout(activityType: dailyPlan.activityType, name: dailyPlan.title, segments: segments, fallbackDuration: 30, fallbackDistance: nil)
    }
    
    // Conversão 2: De AIWorkoutPlan
    func createCustomWorkout(from plan: AIWorkoutPlan) async -> CustomWorkout? {
        return await buildCustomWorkout(activityType: "Running", name: plan.title, segments: plan.segments, fallbackDuration: plan.duration, fallbackDistance: plan.distance)
    }

    // Builder Logic
    private func buildCustomWorkout(activityType: String, name: String, segments: [WorkoutSegment]?, fallbackDuration: Int, fallbackDistance: Double?) async -> CustomWorkout? {
        
        var warmupStep: WorkoutStep?
        var cooldownStep: WorkoutStep?
        var blocks: [IntervalBlock] = []
        
        if let segments = segments, !segments.isEmpty {
            for segment in segments {
                // Ignora segmentos inválidos
                if (segment.durationMinutes ?? 0) <= 0 && (segment.distanceKm ?? 0) <= 0 { continue }
                
                let goal = createGoal(from: segment)
                let alert = createAlert(from: segment) // Cria alerta de BPM ou Pace
                
                switch segment.role {
                case .warmup:
                    warmupStep = WorkoutStep(goal: goal, alert: alert)
                case .cooldown:
                    cooldownStep = WorkoutStep(goal: goal, alert: alert)
                case .work, .recovery:
                    let purpose: IntervalStep.Purpose = (segment.role == .recovery) ? .recovery : .work
                    let step = IntervalStep(purpose, goal: goal, alert: alert)
                    
                    let iterations = segment.reps ?? 1
                    if iterations > 1 {
                        blocks.append(IntervalBlock(steps: [step], iterations: iterations))
                    } else {
                        blocks.append(IntervalBlock(steps: [step], iterations: 1))
                    }
                }
            }
        }
        
        // Fallback se não houver segmentos
        if blocks.isEmpty {
            let goal: WorkoutGoal
            if let dist = fallbackDistance, dist > 0 { goal = .distance(dist, .kilometers) }
            else {
                let duration = fallbackDuration > 0 ? Double(fallbackDuration) : 30.0
                goal = .time(duration, .minutes)
            }
            blocks.append(IntervalBlock(steps: [IntervalStep(.work, goal: goal)], iterations: 1))
        }
        
        return CustomWorkout(activity: .running, location: .outdoor, displayName: name, warmup: warmupStep, blocks: blocks, cooldown: cooldownStep)
    }
    
    private func createGoal(from segment: WorkoutSegment) -> WorkoutGoal {
        switch segment.goalType {
        case .distance:
            if let dist = segment.distanceKm, dist > 0 { return .distance(dist, .kilometers) }
        case .time:
            if let dur = segment.durationMinutes, dur > 0 { return .time(dur, .minutes) }
        case .open: return .open
        }
        return .time(5, .minutes)
    }
    
    // 🔥 INTELIGÊNCIA DE ALERTAS (BPM & PACE)
    private func createAlert(from segment: WorkoutSegment) -> (any WorkoutAlert)? {
        // 1. Prioridade: Pace (Se houver Pace Alvo, cria alerta de velocidade)
        if let minStr = segment.targetPaceMin, let maxStr = segment.targetPaceMax,
           let minSpeed = paceToSpeed(pace: maxStr), // Invertido pois Pace maior = Vel menor
           let maxSpeed = paceToSpeed(pace: minStr) {
            
            // Cria alerta de velocidade (km/h convertidos para m/s)
            return SpeedRangeAlert(target: minSpeed...maxSpeed, metric: .current)
        }
        
        // 2. Fallback: Zona Cardíaca (Interpreta texto da IA)
        let intensity = segment.intensity.lowercased()
        if let (lower, upper) = mapIntensityToHeartRate(intensity: intensity) {
            let lowerBound = Measurement(value: Double(lower), unit: UnitFrequency.beatsPerMinute)
            let upperBound = Measurement(value: Double(upper), unit: UnitFrequency.beatsPerMinute)
            return HeartRateRangeAlert(target: lowerBound...upperBound)
        }
        
        return nil
    }
    
    // Tradutor de Intensidade Enterprise
    private func mapIntensityToHeartRate(intensity: String) -> (Int, Int)? {
        let text = intensity.lowercased()
        
        // Zonas Explícitas
        if text.contains("z1") || text.contains("recuperação") { return (100, 130) }
        if text.contains("z2") || text.contains("aeróbico") || text.contains("leve") { return (130, 145) }
        if text.contains("z3") || text.contains("tempo") || text.contains("moderado") { return (145, 160) }
        if text.contains("z4") || text.contains("limiar") || text.contains("forte") { return (160, 175) }
        if text.contains("z5") || text.contains("vo2") || text.contains("tiro") || text.contains("máximo") { return (175, 195) }
        
        // Fallbacks Genéricos
        if text.contains("easy") { return (120, 140) }
        if text.contains("hard") { return (160, 185) }
        
        return nil
    }
    
    // Converte Pace "5:00" (/km) para Velocidade (m/s)
    private func paceToSpeed(pace: String) -> Measurement<UnitSpeed>? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2,
              let min = Double(parts[0]),
              let sec = Double(parts[1]) else { return nil }
        
        let totalSecondsPerKm = (min * 60) + sec
        if totalSecondsPerKm == 0 { return nil }
        
        let metersPerSecond = 1000.0 / totalSecondsPerKm
        return Measurement(value: metersPerSecond, unit: UnitSpeed.metersPerSecond)
    }
}
