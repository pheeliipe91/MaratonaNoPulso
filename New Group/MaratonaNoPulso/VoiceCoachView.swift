import SwiftUI

struct VoiceCoachView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var aiService = AIService()
    @StateObject private var healthKitManager = HealthKitManager()
    
    @State private var isLoading = false
    @State private var showWorkoutPreview = false
    @State private var generatedWorkout: WorkoutPlan?
    @State private var workoutResult: String = ""
    
    @State private var currentStep: AppStep = .listening

    enum AppStep {
        case listening, processing, preview, result
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text("Maratona no Pulso")
                    .font(.title2)
                    .foregroundColor(.white)

                // Conteúdo principal
                Group {
                    switch currentStep {
                    case .listening:
                        listeningView
                    case .processing:
                        processingView
                    case .preview:
                        workoutPreviewView
                    case .result:
                        resultView
                    }
                }

                Spacer()

                // Botão de ação
                actionButton
            }
            .padding()
        }
        .onAppear {
            Task {
                _ = await healthKitManager.requestAuthorization()
            }
        }
    }
    
    // MARK: - Views
    private var listeningView: some View {
        VStack {
            Text("🎤")
                .font(.system(size: 60))
            Text(audioManager.isListening ? "Ouvindo... fale seu objetivo" : "TOQUE PARA FALAR")
                .font(.title2)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            if !audioManager.transcribedText.isEmpty {
                Text("\"\(audioManager.transcribedText)\"")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }
    
    private var processingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("🤖 AI está criando seu treino...")
                .font(.title2)
                .foregroundColor(.white)
                .padding(.top)
        }
    }
    
    private var workoutPreviewView: some View {
        VStack(spacing: 16) {
            Text("📋 SEU TREINO PERSONALIZADO")
                .font(.headline)
                .foregroundColor(.white)
            
            if let workout = generatedWorkout {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🏃‍♂️ \(workout.duration_minutes) minutos")
                    Text("📏 \(String(format: "%.1f", workout.distance_km ?? 0)) km")
                    Text("🎯 Pace: \(String(format: "%.2f", workout.pace_min_per_km ?? 0)) min/km")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue.opacity(0.3))
                .cornerRadius(12)
            }
            
            Text("Enviar para Apple Watch?")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var resultView: some View {
        VStack {
            Text(workoutResult.contains("✅") ? "✅" : "❌")
                .font(.system(size: 60))
            Text(workoutResult)
                .font(.title3)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    // MARK: - Botão
    private var actionButton: some View {
        Button(action: handleAction) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 70, height: 70)
                
                Image(systemName: buttonIcon)
                    .font(.system(size: 30))
                    .foregroundColor(.black)
            }
        }
        .padding(.bottom, 30)
        .disabled(isLoading)
    }
    
    private var buttonColor: Color {
        switch currentStep {
        case .listening: return audioManager.isListening ? .red : .white
        case .processing: return .gray
        case .preview: return .green
        case .result: return .blue
        }
    }
    
    private var buttonIcon: String {
        switch currentStep {
        case .listening: return audioManager.isListening ? "stop.fill" : "mic.fill"
        case .processing: return "hourglass"
        case .preview: return "applewatch"
        case .result: return "arrow.clockwise"
        }
    }
    
    // MARK: - Ações
    private func handleAction() {
        switch currentStep {
        case .listening:
            audioManager.toggleRecording()
            if !audioManager.isListening && !audioManager.transcribedText.isEmpty {
                processAudio()
            }
            
        case .processing:
            break
            
        case .preview:
            sendToAppleWatch()
            
        case .result:
            resetFlow()
        }
    }
    
    private func processAudio() {
        guard !audioManager.transcribedText.isEmpty else {
            workoutResult = "Não consegui entender. Tente novamente."
            currentStep = .result
            return
        }
        
        currentStep = .processing
        isLoading = true
        
        Task {
            if let workoutPlan = await aiService.generateWorkoutPlan(from: audioManager.transcribedText) {
                
                await MainActor.run {
                    if let moreInfo = workoutPlan.needsMoreInfo {
                        workoutResult = "🤔 \(moreInfo)"
                        currentStep = .result
                    } else {
                        generatedWorkout = workoutPlan
                        currentStep = .preview
                    }
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    workoutResult = "❌ Erro ao gerar treino"
                    currentStep = .result
                    isLoading = false
                }
            }
        }
    }
    
    private func sendToAppleWatch() {
        guard let workout = generatedWorkout else { return }
        
        currentStep = .processing
        
        Task {
            let success = await healthKitManager.createWorkoutFromPlan(workout)
            
            await MainActor.run {
                workoutResult = success ?
                    "✅ Treino enviado para Apple Watch!" :
                    "❌ Erro ao enviar para Apple Watch"
                currentStep = .result
            }
        }
    }
    
    private func resetFlow() {
        currentStep = .listening
        workoutResult = ""
        generatedWorkout = nil
        audioManager.transcribedText = ""
    }
}

#Preview {
    VoiceCoachView()
}
