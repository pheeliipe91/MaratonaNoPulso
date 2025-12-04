import SwiftUI
import Combine
import HealthKit

struct WeeklyPlanView: View {
    @State private var userProfile = AIUserProfile(
        name: "Corredor",
        experienceLevel: "Intermediário",
        goal: "Maratona",
        daysPerWeek: 4,
        currentDistance: 30.0
    )
    
    @State private var weeklyPlan: [DailyPlan] = []
    @State private var showSaveConfirmation = false
    
    // SERVIÇOS
    @StateObject private var aiService = AIService.shared  // 🔥 Usando singleton
    @StateObject private var hkManager = HealthKitManager.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                if weeklyPlan.isEmpty {
                    emptyStateView
                } else {
                    planListView
                }
            }
            .navigationTitle("Plano de Treino")
            .alert("Sucesso", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Treino salvo na sua biblioteca!")
            }
            // Observando mudanças na IA
            .onChange(of: aiService.suggestedWorkouts) { oldWorkouts, newWorkouts in
                if !newWorkouts.isEmpty {
                    addGeneratedWorkoutsToPlan(newWorkouts)
                }
            }
            .onAppear {
                hkManager.fetchAllData()
            }
        }
    }
    
    // MARK: - Subviews
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Gerar Próximo Treino")
                .font(.title2)
            
            VStack {
                TextField("Objetivo", text: $userProfile.goal)
                    .textFieldStyle(.roundedBorder)
                Stepper("Dias/Semana: \(userProfile.daysPerWeek)", value: $userProfile.daysPerWeek, in: 1...7)
            }
            .padding()
            .frame(maxWidth: 300)
            
            Button(action: generatePlan) {
                if aiService.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Solicitar à IA").bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(aiService.isLoading)
            
            if let error = aiService.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
    }
    
    var planListView: some View {
        List {
            ForEach(weeklyPlan) { dayPlan in
                VStack(alignment: .leading) {
                    HStack {
                        Text(dayPlan.day).font(.caption).bold().foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "figure.run").foregroundStyle(.blue)
                    }
                    
                    Text(dayPlan.title).font(.headline)
                    Text(dayPlan.description).font(.caption).lineLimit(2).foregroundStyle(.secondary)
                    
                    if let phase = dayPlan.cyclePhase {
                        Text(phase).font(.caption2).padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4).padding(.top, 2)
                    }
                    
                    Button(action: { saveToLibrary(plan: dayPlan) }) {
                        Label("Salvar na Biblioteca", systemImage: "arrow.down.doc").font(.caption)
                    }
                    .buttonStyle(.borderless).padding(.top, 5)
                }
                .padding(.vertical, 4)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Limpar") { weeklyPlan = [] }
            }
        }
    }
    
    // MARK: - Logic
    
    func generatePlan() {
        var existingPlans: [DailyPlan] = []
        if let data = UserDefaults.standard.data(forKey: "saved_workouts"),
           let saved = try? JSONDecoder().decode([DailyPlan].self, from: data) {
            existingPlans = saved
        }
        
        var healthStats = "Resumo dos últimos 7 dias:\n"
        healthStats += "- Volume Total: \(String(format: "%.1f", hkManager.weeklyDistance)) km\n"
        
        let sortedHistory = hkManager.dailyHistory.sorted(by: { $0.date > $1.date })
        if sortedHistory.isEmpty {
            healthStats += "  (Sem dados recentes)\n"
        } else {
            for activity in sortedHistory.prefix(7) {
                let dist = String(format: "%.1f", activity.distance)
                healthStats += "  - \(activity.day): \(dist) km\n"
            }
        }

        aiService.generateWeekPlan(
            for: userProfile,
            healthContext: healthStats,
            instruction: "Gere sua semana de treino focada no objetivo.",
            existingPlans: existingPlans
        )
    }
    
    func addGeneratedWorkoutsToPlan(_ workouts: [AIWorkoutPlan]) {
        self.weeklyPlan.removeAll()
        for workout in workouts {
            var structureJson: String? = nil
            if let segments = workout.segments, !segments.isEmpty,
               let encodedData = try? JSONEncoder().encode(segments) {
                structureJson = String(data: encodedData, encoding: .utf8)
            }
            
            let finalDescription = workout.description ?? workout.rawInstructionText ?? "Treino gerado por IA."
            
            let newPlan = DailyPlan(
                id: UUID(),
                day: workout.suggestedDay ?? "Dia",
                activityType: "running",
                title: workout.title,
                description: finalDescription,
                structure: structureJson,
                isCompleted: false,
                sourceIcon: "waveform.path.ecg",
                sourceLabel: "Coach AI",
                safetyBadge: workout.difficultyRating,
                coachTips: workout.zoneFocus,
                cyclePhase: workout.cyclePhase,
                cycleTarget: workout.cycleTarget,
                rawInstructionText: workout.rawInstructionText,
                workoutReasoning: workout.workoutReasoning
            )
            self.weeklyPlan.append(newPlan)
        }
    }
    
    func saveToLibrary(plan: DailyPlan) {
        var savedWorkouts: [DailyPlan] = []
        if let data = UserDefaults.standard.data(forKey: "saved_workouts"),
           let decoded = try? JSONDecoder().decode([DailyPlan].self, from: data) {
            savedWorkouts = decoded
        }
        
        let newWorkout = DailyPlan(
            id: UUID(),
            day: plan.day,
            activityType: plan.activityType,
            title: plan.title,
            description: plan.description,
            structure: plan.structure,
            isCompleted: false,
            sourceIcon: plan.sourceIcon,
            sourceLabel: plan.sourceLabel,
            safetyBadge: plan.safetyBadge,
            coachTips: plan.coachTips,
            cyclePhase: plan.cyclePhase,
            cycleTarget: plan.cycleTarget,
            rawInstructionText: plan.rawInstructionText,
            workoutReasoning: plan.workoutReasoning
        )
        
        savedWorkouts.insert(newWorkout, at: 0)
        
        if let encoded = try? JSONEncoder().encode(savedWorkouts) {
            UserDefaults.standard.set(encoded, forKey: "saved_workouts")
            showSaveConfirmation = true
        }
    }
}
