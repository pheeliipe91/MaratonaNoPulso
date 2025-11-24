import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    
    let healthStore = HKHealthStore()
    
    // Propriedade publicada para observar mudanças de autorização
    @Published var authorizationStatus: Bool = false
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ DEBUG: HealthKit não está disponível neste dispositivo.")
            return false
        }
        
        let typesToShare: Set = [
            HKObjectType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            print("✅ DEBUG: Autorização do HealthKit solicitada.")
            
            // Atualiza o status publicado
            await MainActor.run {
                self.authorizationStatus = true
            }
            
            return true
        } catch {
            print("❌ DEBUG: ERRO ao solicitar autorização do HealthKit: \(error.localizedDescription)")
            return false
        }
    }
    
    // Função SIMPLIFICADA - compatível com versões mais antigas
    func createCustomWorkout(title: String, goalInKilometers: Double) async -> Bool {
        print("🚀 DEBUG: Criando treino personalizado no HealthKit...")
        
        let distanceInMeters = goalInKilometers * 1000
        let duration = 3600.0 // 1 hora em segundos
        
        let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: distanceInMeters)
        
        let workout = HKWorkout(
            activityType: .running,
            start: Date(),
            end: Date().addingTimeInterval(duration),
            duration: duration,
            totalEnergyBurned: nil,
            totalDistance: distanceQuantity,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "Maratona no Pulso",
                "WorkoutDisplayName": title
            ]
        )
        
        do {
            try await healthStore.save(workout)
            print("✅ DEBUG: Treino '\(title)' criado com sucesso!")
            return true
        } catch {
            print("❌ DEBUG: ERRO ao criar o treino no HealthKit: \(error.localizedDescription)")
            return false
        }
    }
    
    // 🎯 VERSÃO PRINCIPAL ATUALIZADA - funciona em simulador e dispositivo
    func createWorkoutFromPlan(_ workoutPlan: WorkoutPlan) async -> Bool {
        print("🚀 DEBUG: Criando workout para Apple Watch...")
        
        #if targetEnvironment(simulator)
        // NO SIMULADOR: Simula sucesso para testar o fluxo UI
        print("✅ DEBUG: SIMULADOR - Treino simulado com sucesso!")
        // Pequeno delay para parecer real
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 segundo
        return true
        #else
        // EM DISPOSITIVO FÍSICO: Código real do HealthKit
        return await createRealWorkout(workoutPlan)
        #endif
    }
    
    // FUNÇÃO PRIVADA para criar workout real em dispositivo físico
    private func createRealWorkout(_ workoutPlan: WorkoutPlan) async -> Bool {
        print("📱 DEBUG: Dispositivo físico - criando workout real...")
        
        let distanceInMeters = (workoutPlan.distance_km ?? 5.0) * 1000
        let duration = Double(workoutPlan.duration_minutes) * 60 // converte para segundos
        
        let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: distanceInMeters)
        
        var energyBurned: HKQuantity? = nil
        if let calories = workoutPlan.calories_goal {
            energyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: Double(calories))
        }
        
        let workout = HKWorkout(
            activityType: .running,
            start: Date(),
            end: Date().addingTimeInterval(duration),
            duration: duration,
            totalEnergyBurned: energyBurned,
            totalDistance: distanceQuantity,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "Maratona no Pulso",
                "WorkoutDisplayName": "Treino Personalizado - \(workoutPlan.duration_minutes)min",
                "ai_generated": "true",
                "target_pace": workoutPlan.pace_min_per_km ?? 0,
                "workout_type": workoutPlan.workout_type
            ]
        )
        
        do {
            try await healthStore.save(workout)
            print("✅ DEBUG: Treino AI criado com SUCESSO no Apple Watch!")
            print("📊 Detalhes: \(workoutPlan.duration_minutes)min, \(workoutPlan.distance_km ?? 0)km")
            return true
            
        } catch {
            print("❌ DEBUG: ERRO ao criar treino AI: \(error.localizedDescription)")
            return false
        }
    }
    
    // FUNÇÃO ADICIONAL: Para buscar treinos existentes
    func getRecentWorkouts() async -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 10,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let workouts = samples as? [HKWorkout] {
                    continuation.resume(returning: workouts)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }
}
