import SwiftUI
import WorkoutKit // Importante

struct VoiceCoachView: View {
    @StateObject private var workoutManager = WorkoutKitManager.shared
    
    // Estado para controlar a apresentação do treino
    @State private var showWorkoutPreview = false
    @State private var generatedWorkout: CustomWorkout?
    
    // Seu plano vindo da AI
    @State var currentPlan: WorkoutPlan?
    
    var body: some View {
        VStack {
            // ... sua interface atual ...
            
            Button("Salvar no App Fitness 🏃") {
                if let plan = currentPlan {
                    // 1. Converter o plano da AI em CustomWorkout
                    self.generatedWorkout = workoutManager.createCustomWorkout(from: plan)
                    
                    // 2. Disparar o preview nativo da Apple
                    if self.generatedWorkout != nil {
                        self.showWorkoutPreview = true
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        // 3. O Modifier Mágico que abre a tela da Apple
        .workoutPreview(generatedWorkout, isPresented: $showWorkoutPreview)
    }
}
