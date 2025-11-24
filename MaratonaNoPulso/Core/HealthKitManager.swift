import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    
    let healthStore = HKHealthStore()
    
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
            
            await MainActor.run {
                self.authorizationStatus = true
            }
            return true
        } catch {
            print("❌ DEBUG: ERRO ao solicitar autorização do HealthKit: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Funções de Criação (Histórico)
    
    func createWorkoutFromPlan(_ workoutPlan: AIWorkoutPlan) async -> Bool {
        #if targetEnvironment(simulator)
        print("✅ DEBUG: SIMULADOR - Treino salvo (simulado)!")
        return true
        #else
        return await createRealWorkout(workoutPlan)
        #endif
    }
    
    private func createRealWorkout(_ workoutPlan: AIWorkoutPlan) async -> Bool {
        print("📱 DEBUG: Salvando treino no histórico do HealthKit...")
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        let startDate = Date()
        let duration = Double(workoutPlan.duration_minutes) * 60
        let endDate = startDate.addingTimeInterval(duration)
        
        do {
            try await builder.beginCollection(at: startDate)
            
            let metadata: [String: Any] = [
                HKMetadataKeyWorkoutBrandName: "Maratona no Pulso",
                "WorkoutDisplayName": "Treino AI - \(workoutPlan.duration_minutes)min",
                "ai_generated": true
            ]
            try await builder.addMetadata(metadata)
            
            try await builder.endCollection(at: endDate)
            
            // CORREÇÃO: Desembrulhando o opcional com segurança
            if let workout = try await builder.finishWorkout() {
                print("✅ Treino salvo no Histórico com sucesso! UUID: \(workout.uuid)")
                return true
            } else {
                print("❌ Erro: Builder finalizou mas não retornou um objeto workout válido.")
                return false
            }
            
        } catch {
            print("❌ Erro ao salvar treino no HealthKit: \(error.localizedDescription)")
            return false
        }
    }
}
