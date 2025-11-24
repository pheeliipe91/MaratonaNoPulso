import Foundation
import WorkoutKit
import HealthKit
import Combine

class WorkoutKitManager: ObservableObject {
    
    static let shared = WorkoutKitManager()
    
    private init() {}
    
    // Placeholder estático
    static let emptyPlan: WorkoutKit.WorkoutPlan = {
        let step = IntervalStep(.work, goal: .time(1, .minutes))
        let block = IntervalBlock(steps: [step], iterations: 1)
        let workout = CustomWorkout(activity: .running, location: .outdoor, displayName: "Empty", warmup: nil, blocks: [block], cooldown: nil)
        return WorkoutKit.WorkoutPlan(.custom(workout))
    }()
    
    func requestAuthorization() async -> Bool { return true }

    // MARK: - Conversão 1: De DailyWorkout (Plano Semanal)
    func createCustomWorkout(from dailyWorkout: DailyWorkout) -> CustomWorkout? {
        return buildCustomWorkout(
            type: dailyWorkout.workout_type,
            name: dailyWorkout.workout_name,
            segments: dailyWorkout.segments,
            fallbackDuration: dailyWorkout.duration_minutes,
            fallbackDistance: dailyWorkout.distance_km
        )
    }
    
    // MARK: - Conversão 2: De AIWorkoutPlan (Treino Avulso) <--- TIPO CORRIGIDO
    func createCustomWorkout(from plan: AIWorkoutPlan) -> CustomWorkout? {
        let type = WorkoutType.from(string: plan.workout_type)
        
        return buildCustomWorkout(
            type: type,
            name: "Treino Personalizado",
            segments: plan.segments,
            fallbackDuration: plan.duration_minutes,
            fallbackDistance: plan.distance_km
        )
    }

    // MARK: - Lógica de Construção
    private func buildCustomWorkout(type: WorkoutType, name: String, segments: [WorkoutSegment]?, fallbackDuration: Int, fallbackDistance: Double?) -> CustomWorkout? {
        var warmupStep: WorkoutStep?
        var cooldownStep: WorkoutStep?
        var blocks: [IntervalBlock] = []
        
        if let segments = segments, !segments.isEmpty {
            for segment in segments {
                let segType = segment.type.lowercased()
                
                if segType.contains("warm") {
                    warmupStep = createSingleStep(duration: segment.duration_minutes)
                } else if segType.contains("cool") {
                    cooldownStep = createSingleStep(duration: segment.duration_minutes)
                } else {
                    let purpose: IntervalStep.Purpose = segType.contains("recovery") ? .recovery : .work
                    let step = createIntervalStep(purpose: purpose, duration: segment.duration_minutes)
                    blocks.append(IntervalBlock(steps: [step], iterations: 1))
                }
            }
        } else {
            let step = createIntervalStep(purpose: .work, duration: fallbackDuration)
            blocks.append(IntervalBlock(steps: [step], iterations: 1))
        }
        
        let activity: HKWorkoutActivityType
        switch type {
            case .outdoor_run, .indoor_run: activity = .running
            case .walk: activity = .walking
            case .cross_training: activity = .crossTraining
            default: activity = .running
        }
        
        return CustomWorkout(
            activity: activity,
            location: .outdoor,
            displayName: name,
            warmup: warmupStep,
            blocks: blocks,
            cooldown: cooldownStep
        )
    }
    
    private func createSingleStep(duration: Int) -> WorkoutStep {
        return WorkoutStep(goal: .time(Double(duration), .minutes))
    }
    
    private func createIntervalStep(purpose: IntervalStep.Purpose, duration: Int) -> IntervalStep {
        return IntervalStep(purpose, goal: .time(Double(duration), .minutes))
    }
}
