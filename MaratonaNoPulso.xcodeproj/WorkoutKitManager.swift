import Foundation
import WorkoutKit
import HealthKit

@MainActor
class WorkoutKitManager: ObservableObject {
    
    @Published var authorizationStatus: WorkoutPlan.AuthorizationState = .undetermined
    @Published var savedWorkouts: [ScheduledWorkoutPlan] = []
    
    // MARK: - Autorização
    
    func requestAuthorization() async -> Bool {
        do {
            let status = try await WorkoutPlan.requestAuthorization()
            self.authorizationStatus = status
            print("✅ WorkoutKit autorizado: \(status)")
            return status == .authorized
        } catch {
            print("❌ Erro ao solicitar autorização WorkoutKit: \(error)")
            return false
        }
    }
    
    // MARK: - Criar Treino Customizado
    
    func createCustomWorkout(from dailyWorkout: DailyWorkout) async -> CustomWorkout? {
        // Criar blocos de treino baseados nos segmentos
        var blocks: [IntervalBlock] = []
        
        if let segments = dailyWorkout.segments {
            for segment in segments {
                let block = createIntervalBlock(from: segment)
                blocks.append(block)
            }
        } else {
            // Se não tem segmentos, cria um bloco simples
            let simpleBlock = createSimpleBlock(
                duration: dailyWorkout.duration_minutes,
                distance: dailyWorkout.distance_km
            )
            blocks.append(simpleBlock)
        }
        
        // Criar o workout customizado
        let customWorkout = CustomWorkout(
            activity: activityType(for: dailyWorkout.workout_type),
            location: locationFor(dailyWorkout.workout_type),
            displayName: dailyWorkout.workout_name,
            warmup: createWarmupStep(from: dailyWorkout.segments),
            blocks: blocks,
            cooldown: createCooldownStep(from: dailyWorkout.segments)
        )
        
        return customWorkout
    }
    
    // MARK: - Salvar Plano Semanal
    
    func saveWeeklyPlan(_ plan: WeeklyTrainingPlan) async -> Bool {
        var successCount = 0
        
        for workout in plan.workouts where !workout.is_rest_day {
            guard let customWorkout = await createCustomWorkout(from: workout) else {
                print("❌ Falha ao criar workout: \(workout.workout_name)")
                continue
            }
            
            // Calcular a data do treino (hoje + dias)
            let workoutDate = Calendar.current.date(
                byAdding: .day,
                value: workout.day - 1,
                to: Date()
            ) ?? Date()
            
            // Agendar o treino
            let scheduledWorkout = ScheduledWorkoutPlan(
                plan: .custom(customWorkout),
                date: .date(workoutDate)
            )
            
            do {
                try await WorkoutScheduler.shared.schedule(scheduledWorkout)
                savedWorkouts.append(scheduledWorkout)
                successCount += 1
                print("✅ Treino agendado: \(workout.workout_name) para \(workoutDate)")
            } catch {
                print("❌ Erro ao agendar treino: \(error)")
            }
        }
        
        let totalNonRestDays = plan.workouts.filter { !$0.is_rest_day }.count
        print("📊 Treinos salvos: \(successCount)/\(totalNonRestDays)")
        
        return successCount > 0
    }
    
    // MARK: - Helpers
    
    private func activityType(for type: WorkoutType) -> HKWorkoutActivityType {
        switch type {
        case .outdoor_run:
            return .running
        case .indoor_run:
            return .running
        case .walk:
            return .walking
        case .cross_training:
            return .crossTraining
        case .rest:
            return .other
        }
    }
    
    private func locationFor(_ type: WorkoutType) -> HKWorkoutSessionLocationType {
        switch type {
        case .outdoor_run, .walk:
            return .outdoor
        case .indoor_run, .cross_training:
            return .indoor
        case .rest:
            return .unknown
        }
    }
    
    private func createIntervalBlock(from segment: WorkoutSegment) -> IntervalBlock {
        // Criar um step com a duração do segmento
        let step = IntervalStep(
            .work,
            purpose: purposeFor(segment.type)
        )
        
        // Configurar o goal baseado na duração
        step.goal = .time(Double(segment.duration_minutes) * 60, .seconds)
        
        // Configurar o alert baseado no pace alvo se disponível
        if let targetPace = segment.target_pace {
            let paceInSecondsPerKm = targetPace * 60
            step.alert = .pace(
                target: paceInSecondsPerKm,
                unit: .secondsPerKilometer
            )
        }
        
        return IntervalBlock(steps: [step], iterations: 1)
    }
    
    private func createSimpleBlock(duration: Int, distance: Double?) -> IntervalBlock {
        let step = IntervalStep(.work)
        
        if let distance = distance {
            step.goal = .distance(distance, .kilometers)
        } else {
            step.goal = .time(Double(duration) * 60, .seconds)
        }
        
        return IntervalBlock(steps: [step], iterations: 1)
    }
    
    private func purposeFor(_ segmentType: String) -> IntervalStep.Purpose {
        switch segmentType.lowercased() {
        case "warmup", "warm_up":
            return .warmUp
        case "cooldown", "cool_down":
            return .coolDown
        case "recovery":
            return .recovery
        default:
            return .work
        }
    }
    
    private func createWarmupStep(from segments: [WorkoutSegment]?) -> WorkoutStep? {
        guard let segments = segments,
              let warmup = segments.first(where: { $0.type.lowercased().contains("warm") }) else {
            return nil
        }
        
        let step = SingleGoalWorkoutStep(goal: .time(Double(warmup.duration_minutes) * 60, .seconds))
        return step
    }
    
    private func createCooldownStep(from segments: [WorkoutSegment]?) -> WorkoutStep? {
        guard let segments = segments,
              let cooldown = segments.first(where: { $0.type.lowercased().contains("cool") }) else {
            return nil
        }
        
        let step = SingleGoalWorkoutStep(goal: .time(Double(cooldown.duration_minutes) * 60, .seconds))
        return step
    }
    
    // MARK: - Buscar Treinos Agendados
    
    func fetchScheduledWorkouts() async {
        do {
            let workouts = try await WorkoutScheduler.shared.scheduledWorkouts
            self.savedWorkouts = workouts
            print("📋 Treinos agendados encontrados: \(workouts.count)")
        } catch {
            print("❌ Erro ao buscar treinos agendados: \(error)")
        }
    }
    
    // MARK: - Remover Treino
    
    func removeScheduledWorkout(_ workout: ScheduledWorkoutPlan) async {
        do {
            try await WorkoutScheduler.shared.remove(workout)
            savedWorkouts.removeAll { $0.id == workout.id }
            print("🗑️ Treino removido com sucesso")
        } catch {
            print("❌ Erro ao remover treino: \(error)")
        }
    }
}
