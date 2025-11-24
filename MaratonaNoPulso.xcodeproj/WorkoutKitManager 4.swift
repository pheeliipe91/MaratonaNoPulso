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

@MainActor
class WorkoutKitManager: ObservableObject {
    
    @Published var savedWorkoutIds: [UUID] = []
    @Published var scheduledWorkoutsCount: Int = 0
    @Published var lastError: String = ""
    @Published var exportedWorkoutURLs: [URL] = []
    
    // MARK: - Autorizacao
    
    func requestAuthorization() async -> Bool {
        print("WorkoutKit pronto para uso")
        return true
    }
    
    // MARK: - Criar Treino Customizado
    
    func createCustomWorkout(from dailyWorkout: DailyWorkout) -> CustomWorkout? {
        var blocks: [IntervalBlock] = []
        
        if let segments = dailyWorkout.segments {
            for segment in segments where segment.type.lowercased() == "main" {
                let block = createIntervalBlock(from: segment)
                blocks.append(block)
            }
        }
        
        if blocks.isEmpty {
            let simpleBlock = createSimpleBlock(
                duration: dailyWorkout.duration_minutes,
                distance: dailyWorkout.distance_km
            )
            blocks.append(simpleBlock)
        }
        
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
    
    // MARK: - Salvar Plano Semanal (exporta arquivos .workout)
    
    func saveWeeklyPlan(_ plan: WeeklyTrainingPlan) async -> Bool {
        var successCount = 0
        var urls: [URL] = []
        
        for workout in plan.workouts where !workout.is_rest_day {
            guard let customWorkout = createCustomWorkout(from: workout) else {
                print("Falha ao criar workout: \(workout.workout_name)")
                continue
            }
            
            // Exportar o treino como arquivo .workout
            do {
                let url = try customWorkout.exportToURL()
                urls.append(url)
                successCount += 1
                print("Treino exportado: \(workout.workout_name)")
            } catch {
                print("Erro ao exportar: \(workout.workout_name) - \(error.localizedDescription)")
                lastError = error.localizedDescription
            }
        }
        
        let totalNonRestDays = plan.workouts.filter { !$0.is_rest_day }.count
        print("Treinos exportados: \(successCount)/\(totalNonRestDays)")
        
        scheduledWorkoutsCount = successCount
        exportedWorkoutURLs = urls
        
        return successCount > 0
    }
    
    // MARK: - Salvar Treino Individual
    
    func saveWorkout(_ dailyWorkout: DailyWorkout, for date: Date) async -> Bool {
        guard let customWorkout = createCustomWorkout(from: dailyWorkout) else {
            print("Falha ao criar workout: \(dailyWorkout.workout_name)")
            return false
        }
        
        do {
            let url = try customWorkout.exportToURL()
            exportedWorkoutURLs = [url]
            print("Treino exportado: \(dailyWorkout.workout_name)")
            return true
        } catch {
            print("Erro ao exportar: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return false
        }
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
        let seconds = Double(segment.duration_minutes) * 60
        let goal = WorkoutGoal.time(seconds, .seconds)
        let step = IntervalStep(.work, goal: goal)
        return IntervalBlock(steps: [step], iterations: 1)
    }
    
    private func createSimpleBlock(duration: Int, distance: Double?) -> IntervalBlock {
        let goal: WorkoutGoal
        
        if let distance = distance {
            goal = .distance(distance, .kilometers)
        } else {
            let seconds = Double(duration) * 60
            goal = .time(seconds, .seconds)
        }
        
        let step = IntervalStep(.work, goal: goal)
        return IntervalBlock(steps: [step], iterations: 1)
    }
    
    private func createWarmupStep(from segments: [WorkoutSegment]?) -> WorkoutStep? {
        guard let segments = segments,
              let warmup = segments.first(where: { $0.type.lowercased().contains("warm") }) else {
            return nil
        }
        
        let seconds = Double(warmup.duration_minutes) * 60
        let goal = WorkoutGoal.time(seconds, .seconds)
        return WorkoutStep(goal: goal)
    }
    
    private func createCooldownStep(from segments: [WorkoutSegment]?) -> WorkoutStep? {
        guard let segments = segments,
              let cooldown = segments.first(where: { $0.type.lowercased().contains("cool") }) else {
            return nil
        }
        
        let seconds = Double(cooldown.duration_minutes) * 60
        let goal = WorkoutGoal.time(seconds, .seconds)
        return WorkoutStep(goal: goal)
    }
    
    // MARK: - Buscar Treinos
    
    func fetchScheduledWorkouts() async -> Int {
        return scheduledWorkoutsCount
    }
    
    // MARK: - Remover Treinos
    
    func removeAllScheduledWorkouts() async -> Bool {
        scheduledWorkoutsCount = 0
        exportedWorkoutURLs = []
        return true
    }
}
