import SwiftUI
import WorkoutKit

struct VoiceCoachView: View {
    @StateObject private var workoutManager = WorkoutKitManager.shared
    @StateObject private var audioManager = AudioManager()
    @StateObject private var aiService = AIService()
    
    @State private var appleWorkoutPlan: WorkoutKit.WorkoutPlan?
    @State private var showWorkoutPreview = false
    @State private var isLoading = false
    
    // TIPO CORRIGIDO AQUI
    @State var currentPlan: AIWorkoutPlan?
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(audioManager.transcribedText.isEmpty ? "Toque para falar" : audioManager.transcribedText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
            
            if isLoading {
                ProgressView("Criando treino...")
            }
            
            if let plan = currentPlan {
                VStack {
                    Text("Treino: \(plan.duration_minutes) min")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Button("Salvar no App Fitness 🏃") {
                        if let customWorkout = workoutManager.createCustomWorkout(from: plan) {
                            self.appleWorkoutPlan = WorkoutKit.WorkoutPlan(.custom(customWorkout))
                            self.showWorkoutPreview = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            
            Spacer()
            
            Button {
                if audioManager.isListening {
                    audioManager.stopRecording()
                    generateWorkout()
                } else {
                    audioManager.startRecording()
                }
            } label: {
                Image(systemName: audioManager.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(audioManager.isListening ? .red : .blue)
            }
            .padding(.bottom, 40)
        }
        .workoutPreview(appleWorkoutPlan ?? WorkoutKitManager.emptyPlan, isPresented: $showWorkoutPreview)
    }
    
    func generateWorkout() {
        isLoading = true
        Task {
            // Chamada atualizada retorna AIWorkoutPlan
            let result = await aiService.generateWorkoutPlan(from: audioManager.transcribedText)
            await MainActor.run {
                self.currentPlan = result
                self.isLoading = false
            }
        }
    }
}
