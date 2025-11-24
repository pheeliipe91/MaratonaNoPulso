import SwiftUI
import WorkoutKit

struct WeeklyPlanView: View {
    @StateObject private var aiService = AIService()
    @StateObject private var workoutManager = WorkoutKitManager.shared
    @StateObject private var audioManager = AudioManager()
    
    @State private var appleWorkoutPlan: WorkoutKit.WorkoutPlan?
    @State private var showPreview: Bool = false
    
    @State private var plan: WeeklyTrainingPlan?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fundo Bonito (Cinza Escuro Profundo)
                Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // HEADER (Transcrição)
                    VStack(spacing: 10) {
                        Text(audioManager.isListening ? "🦻 Ouvindo..." : "🎙️ Toque para falar")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        
                        if !audioManager.transcribedText.isEmpty {
                            Text("\"\(audioManager.transcribedText)\"")
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.top)
                    
                    // CONTEÚDO PRINCIPAL
                    if isLoading {
                        VStack {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("Criando treino inteligente...")
                                .foregroundStyle(.white)
                                .padding(.top)
                        }
                        .frame(maxHeight: .infinity)
                        
                    } else if let plan = plan, !plan.workouts.isEmpty {
                        // LISTA DE TREINOS (Visual Card)
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(plan.workouts) { workout in
                                    WorkoutCard(workout: workout) {
                                        if !workout.is_rest_day {
                                            presentWorkoutPreview(for: workout)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    } else {
                        // ESTADO VAZIO / ERRO
                        VStack(spacing: 15) {
                            Image(systemName: "figure.run.square.stack")
                                .font(.system(size: 60))
                                .foregroundStyle(.gray)
                            
                            Text(errorMessage ?? "Nenhum plano gerado ainda.")
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                    // BOTÃO DO MICROFONE
                    Button {
                        toggleRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(audioManager.isListening ? Color.red : Color.blue)
                                .frame(width: 72, height: 72)
                                .shadow(radius: 10)
                            
                            Image(systemName: audioManager.isListening ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .workoutPreview(appleWorkoutPlan ?? WorkoutKitManager.emptyPlan, isPresented: $showPreview)
        }
    }
    
    // MARK: - Componente Visual do Card
    func WorkoutCard(workout: DailyWorkout, action: @escaping () -> Void) -> some View {
        HStack {
            // Ícone do Dia
            VStack {
                Text("DIA")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                Text("\(workout.day)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white)
            }
            .frame(width: 50)
            
            // Detalhes
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workout_name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack {
                    Image(systemName: workout.workout_type.icon)
                    if !workout.is_rest_day {
                        Text("\(workout.duration_minutes) min • \(String(format: "%.1f", workout.distance_km ?? 0)) km")
                    } else {
                        Text("Recuperação")
                    }
                }
                .font(.caption)
                .foregroundStyle(.gray)
            }
            
            Spacer()
            
            // Botão de Adicionar (Só se não for descanso)
            if !workout.is_rest_day {
                Button(action: action) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.green)
                }
            }
        }
        .padding()
        .background(Color(red: 0.18, green: 0.18, blue: 0.2)) // Cinza Card
        .cornerRadius(16)
    }
    
    // MARK: - Lógica
    func toggleRecording() {
        if audioManager.isListening {
            audioManager.stopRecording()
            generatePlan()
        } else {
            errorMessage = nil
            audioManager.startRecording()
        }
    }
    
    func generatePlan() {
        guard !audioManager.transcribedText.isEmpty else { return }
        isLoading = true
        
        Task {
            let result = await aiService.generateWeeklyPlan(from: audioManager.transcribedText)
            
            await MainActor.run {
                self.isLoading = false
                if let validPlan = result {
                    self.plan = validPlan
                } else {
                    self.errorMessage = "Erro ao ler resposta da AI. Tente de novo."
                }
            }
        }
    }
    
    func presentWorkoutPreview(for dailyWorkout: DailyWorkout) {
        if let customWorkout = workoutManager.createCustomWorkout(from: dailyWorkout) {
            self.appleWorkoutPlan = WorkoutKit.WorkoutPlan(.custom(customWorkout))
            self.showPreview = true
        }
    }
}
