//
//  WorkoutKitManager.swift
//  MaratonaNoPulso
//
//  Created by Phelipe de Oliveira Xavier on 24/11/25.
//

import Foundation
import Combine
import WorkoutKit
import HealthKit

// Usar typealias para evitar conflito com WorkoutPlan do Models.swift
typealias WKWorkoutPlan = WorkoutKit.WorkoutPlan

@MainActor
class WorkoutKitManager: ObservableObject {
    
    @Published var savedWorkoutIds: [UUID] = []
    
    // MARK: - Autorização
    
    func requestAuthorization() async -> Bool {
        // WorkoutKit não requer autorização explícita
        // A autorização é feita automaticamente quando você agenda um treino
        print("✅ WorkoutKit pronto para uso")
        return true
    }
    
    // MARK: - Criar Treino Customizado
    
    func createCustomWorkout(from dailyWorkout: DailyWorkout) -> CustomWorkout? {
        // Criar blocos de treino baseados nos segmentos
        var blocks: [IntervalBlock] = []
        
        if let segments = dailyWorkout.segments {
            for segment in segments where segment.type.lowercased() == "main" {
                let block = createIntervalBlock(from: segment)
                blocks.append(block)
            }
        }
        
        // Se não tem blocos, cria um bloco simples
        if blocks.isEmpty {
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
            guard let customWorkout = createCustomWorkout(from: workout) else {
                print("❌ Falha ao criar workout: \(workout.workout_name)")
                continue
            }
            
            // Calcular a data do treino (hoje + dias)
            guard let workoutDate = Calendar.current.date(
                byAdding: .day,
                value: workout.day - 1,
                to: Date()
            ) else {
                continue
            }
            
            // Criar DateComponents para a data
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: workoutDate
            )
            
            // Agendar o treino
            let workoutPlan = WKWorkoutPlan(customWorkout)
            let scheduledWorkout = ScheduledWorkoutPlan(
                workoutPlan,
                date: dateComponents
            )
            
            do {
                try await WorkoutScheduler.shared.schedule(scheduledWorkout)
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
        let goal = WorkoutGoal.time(Double(segment.duration_minutes) * 60)
        let step = IntervalStep(.work, goal: goal)
        
        return IntervalBlock(steps: [step], iterations: 1)
    }
    
    private func createSimpleBlock(duration: Int, distance: Double?) -> IntervalBlock {
        let goal: WorkoutGoal
        
        if let distance = distance {
            goal = .distance(distance, .kilometers)
        } else {
            goal = .time(Double(duration) * 60)
        }
        
        let step = IntervalStep(.work, goal: goal)
        
        return IntervalBlock(steps: [step], iterations: 1)
    }
    
    private func createWarmupStep(from segments: [WorkoutSegment]?) -> WorkoutStep? {
        guard let segments = segments,
              let warmup = segments.first(where: { $0.type.lowercased().contains("warm") }) else {
            return nil
        }
        
        let goal = WorkoutGoal.time(Double(warmup.duration_minutes) * 60)
        return WorkoutStep(goal: goal)
    }
    
    private func createCooldownStep(from segments: [WorkoutSegment]?) -> WorkoutStep? {
        guard let segments = segments,
              let cooldown = segments.first(where: { $0.type.lowercased().contains("cool") }) else {
            return nil
        }
        
        let goal = WorkoutGoal.time(Double(cooldown.duration_minutes) * 60)
        return WorkoutStep(goal: goal)
    }
    
    // MARK: - Buscar Treinos Agendados
    
    func fetchScheduledWorkouts() async {
        do {
            let workouts = try await WorkoutScheduler.shared.scheduledWorkouts
            print("📋 Treinos agendados encontrados: \(workouts.count)")
        } catch {
            print("❌ Erro ao buscar treinos agendados: \(error)")
        }
    }
}
