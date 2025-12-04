import SwiftUI
import WorkoutKit
import SwiftData
import HealthKit // Importante para tipos do HK

struct VoiceCoachView: View {
    @Binding var selectedTab: Int
    
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    
    @StateObject private var workoutManager = WorkoutKitManager.shared
    @StateObject private var audioManager = AudioManager()
    @StateObject private var aiService = AIService.shared  // 🔥 Usando singleton
    @StateObject private var hkManager = HealthKitManager.shared
    
    @State private var showImportSheet = false
    @State private var importedContext: String = ""
    @State private var showConfirmation: Bool = false
    @State private var showSaveAlert = false
    @State private var savedCount: Int = 0
    @State private var savedPlanName: String = ""
    
    @State private var showProfileSheet = false
    @State private var isLoadingHealthData = false  // 🆕

    var body: some View {
        ZStack {
            Color(hex: "0B0B0C").ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                    .padding(.top, 60)
                    .padding(.bottom, 10)
                
                if !importedContext.isEmpty {
                    contextBanner.padding(.bottom, 10)
                }
                
                if isLoadingHealthData {
                    Spacer()
                    VStack(spacing: 20) {
                        ProgressView().tint(.neonGreen).scaleEffect(1.5)
                        Text("CARREGANDO DADOS DO HEALTH...").font(.caption).tracking(2).foregroundStyle(.gray)
                        Text("VO2Max, FC, Paces Reais").font(.caption2).foregroundStyle(.gray)
                    }
                    Spacer()
                }
                else if aiService.isLoading {
                    Spacer()
                    loadingView
                    Spacer()
                }
                else if let error = aiService.errorMessage {
                    Spacer()
                    errorView(message: error)
                    Spacer()
                }
                else if !aiService.suggestedWorkouts.isEmpty {
                    PlanResultDashboard(workouts: aiService.suggestedWorkouts, roadmap: aiService.suggestedRoadmap)
                }
                else {
                    Spacer()
                    emptyStateView
                    Spacer()
                }
                
                if aiService.suggestedWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        if !audioManager.transcribedText.isEmpty {
                            transcriptionView
                        }
                        micButton
                    }
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportPlanSheet(importedText: $importedContext) { }
        }
        .sheet(isPresented: $showProfileSheet) {
            if let user = userProfiles.first {
                ProfileSettingsView(profile: user)
            } else {
                Text("Erro: Perfil não encontrado.")
            }
        }
        .alert("Plano Salvo!", isPresented: $showSaveAlert) {
            Button("Ir para Biblioteca", role: .cancel) {
                aiService.suggestedWorkouts = []
                aiService.suggestedRoadmap = []
                showConfirmation = false
            }
        } message: {
            Text("O plano '\(savedPlanName)' com \(savedCount) treinos foi salvo. Acesse a Biblioteca para gerar os detalhes de cada dia.")
        }
    }
    
    // MARK: - Dashboard Results
    func PlanResultDashboard(workouts: [AIWorkoutPlan], roadmap: [CyclePhase]) -> some View {
        let target = workouts.first?.cycleTarget ?? "PLANO PERSONALIZADO"
        let totalDist = workouts.reduce(0) { $0 + $1.distance }
        
        return GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("ESTRATÉGIA DEFINIDA").font(.caption).bold().tracking(2).foregroundStyle(Color.neonGreen)
                            Text(target.uppercased()).font(.title).bold().foregroundStyle(.white).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                            
                            HStack(spacing: 20) {
                                StatPill(icon: "calendar", value: "\(workouts.count)", label: "Treinos")
                                Divider().frame(height: 20).background(Color.gray)
                                StatPill(icon: "figure.run", value: String(format: "%.0f", totalDist), label: "Km Totais")
                                Divider().frame(height: 20).background(Color.gray)
                                StatPill(icon: "target", value: "Foco", label: roadmap.first?.focus ?? "Geral")
                            }
                            .padding(.top, 10)
                        }
                        .padding(.horizontal)
                        
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                        
                        if !roadmap.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("FASES DO CICLO").font(.caption).bold().foregroundStyle(.gray).padding(.horizontal)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(roadmap) { phase in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(phase.phaseName).font(.headline).bold().foregroundStyle(.black)
                                                Text(phase.duration).font(.caption2).bold().foregroundStyle(.black.opacity(0.7))
                                                Spacer()
                                                Text(phase.focus).font(.caption2).foregroundStyle(.black.opacity(0.6)).lineLimit(2)
                                            }
                                            .padding(12).frame(width: 140, height: 90).background(Color.neonGreen).cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("SEMANA 1 (DETALHADA)").font(.caption).bold().foregroundStyle(.gray)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(workouts.prefix(10)) { workout in
                                    HStack(spacing: 15) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)).frame(width: 50, height: 50)
                                            VStack(spacing: 0) {
                                                Text(String(workout.suggestedDay?.prefix(3) ?? "DIA").uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(Color.neonGreen)
                                                Image(systemName: "figure.run").foregroundStyle(.white)
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(workout.title).font(.subheadline).bold().foregroundStyle(.white)
                                            HStack {
                                                Label("\(Int(workout.distance))km", systemImage: "map")
                                                Label("\(workout.duration)min", systemImage: "clock")
                                            }
                                            .font(.caption2).foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        if let diff = workout.difficultyRating {
                                            Circle().fill(diff == "Alta" ? Color.red : (diff == "Média" ? Color.orange : Color.blue)).frame(width: 8, height: 8)
                                        }
                                    }
                                    .padding(12).background(Color.cardSurface).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                                }
                                if workouts.count > 10 {
                                    Text("+ \(workouts.count - 10) treinos no plano completo...").font(.caption).italic().foregroundStyle(.gray).padding(.top, 5)
                                }
                            }
                            .padding(.horizontal)
                        }
                        Spacer().frame(height: 80)
                    }
                    .padding(.top, 10)
                }
                
                VStack {
                    Divider().background(Color.white.opacity(0.1))
                    HStack(spacing: 15) {
                        Button(action: { withAnimation { aiService.suggestedWorkouts = []; aiService.suggestedRoadmap = [] } }) {
                            Image(systemName: "trash").font(.title3).foregroundStyle(.gray).padding().background(Color.white.opacity(0.1)).clipShape(Circle())
                        }
                        Button(action: { saveBatch(workouts: workouts) }) {
                            HStack { Image(systemName: "folder.fill.badge.plus"); Text("SALVAR PLANO NA BIBLIOTECA") }
                                .font(.headline.bold()).foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 56).background(Color.neonGreen).cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 30).background(Color.appBackground.opacity(0.95))
                }
            }
        }
        .onAppear { showConfirmation = true }
    }
    
    func StatPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) { Image(systemName: icon).font(.caption2).foregroundStyle(Color.neonGreen); Text(value).font(.headline).bold().foregroundStyle(.white) }
            Text(label).font(.caption2).foregroundStyle(.gray)
        }
    }

    func saveBatch(workouts: [AIWorkoutPlan]) {
        var savedPlans: [DailyPlan] = []
        if let data = UserDefaults.standard.data(forKey: "saved_workouts"),
           let decoded = try? JSONDecoder().decode([DailyPlan].self, from: data) {
            savedPlans = decoded
        }
        
        let planName = workouts.first?.cycleTarget ?? workouts.first?.cyclePhase ?? "Plano Personalizado"
        savedCount = workouts.count
        savedPlanName = planName
        
        // 🆕 Gerar ID único para o plano pai
        let parentPlanId = UUID()
        
        // 📊 Agrupar por semana
        let groupedByWeek = Dictionary(grouping: workouts) { $0.weekNumber ?? 1 }
        let sortedWeeks = groupedByWeek.keys.sorted()
        
        print("📦 Salvando plano: \(planName)")
        print("   - Total de treinos: \(workouts.count)")
        print("   - Semanas: \(sortedWeeks.count)")
        
        // 🗂️ Criar plano PAI (container)
        let parentPlan = DailyPlan(
            id: parentPlanId,
            day: "Plano Completo",
            activityType: "plan_container",
            title: planName,
            description: "\(workouts.count) treinos organizados em \(sortedWeeks.count) semanas",
            structure: nil,
            isCompleted: false,
            sourceIcon: "folder.fill",
            sourceLabel: "Plano Gerado",
            safetyBadge: nil,
            coachTips: nil,
            cyclePhase: nil,
            cycleTarget: planName,
            planColor: nil,
            rawInstructionText: nil,
            workoutReasoning: nil,
            isArchived: false,
            strengthParams: nil,
            weekNumber: nil,
            parentPlanId: nil  // É o pai, não tem pai
        )
        
        savedPlans.insert(parentPlan, at: 0)
        
        // 🗂️ Criar sub-planos por SEMANA
        for weekNum in sortedWeeks {
            guard let weekWorkouts = groupedByWeek[weekNum] else { continue }
            
            let weekPlanId = UUID()
            let weekPlan = DailyPlan(
                id: weekPlanId,
                day: "Semana \(weekNum)",
                activityType: "week_container",
                title: "Semana \(weekNum)",
                description: "\(weekWorkouts.count) treinos",
                structure: nil,
                isCompleted: false,
                sourceIcon: "calendar",
                sourceLabel: "Semana",
                safetyBadge: nil,
                coachTips: nil,
                cyclePhase: weekWorkouts.first?.cyclePhase,
                cycleTarget: planName,
                planColor: nil,
                rawInstructionText: nil,
                workoutReasoning: nil,
                isArchived: false,
                strengthParams: nil,
                weekNumber: weekNum,
                parentPlanId: parentPlanId  // Pertence ao plano pai
            )
            
            savedPlans.insert(weekPlan, at: savedPlans.count)  // Adiciona no final
            
            // 💪 Adicionar treinos individuais da semana
            for w in weekWorkouts {
                let safeDescription = w.description ?? w.rawInstructionText ?? "Treino IA"
                
                // Determinar tipo de atividade
                let activityType: String
                if w.type.lowercased().contains("strength") || w.type.lowercased().contains("força") {
                    activityType = "strength"
                } else if w.type.lowercased().contains("rest") || w.type.lowercased().contains("descanso") {
                    activityType = "rest"
                } else {
                    activityType = "running"
                }
                
                let newPlan = DailyPlan(
                    id: UUID(),
                    day: w.suggestedDay ?? "Dia Livre",
                    activityType: activityType,
                    title: w.title,
                    description: safeDescription,
                    structure: nil,
                    isCompleted: false,
                    sourceIcon: "waveform.path.ecg",
                    sourceLabel: "Coach AI",
                    safetyBadge: w.difficultyRating,
                    coachTips: w.zoneFocus,
                    cyclePhase: w.cyclePhase,
                    cycleTarget: planName,
                    planColor: nil,
                    rawInstructionText: w.rawInstructionText,
                    workoutReasoning: w.workoutReasoning,
                    isArchived: false,
                    strengthParams: w.strengthParams,
                    weekNumber: weekNum,
                    parentPlanId: weekPlanId  // Pertence à semana
                )
                
                savedPlans.append(newPlan)
            }
        }
        
        // 💾 Salvar tudo
        if let encoded = try? JSONEncoder().encode(savedPlans) {
            UserDefaults.standard.set(encoded, forKey: "saved_workouts")
            withAnimation { showSaveAlert = true }
            print("✅ Plano salvo com sucesso!")
        }
    }
    
    // MARK: - Components
    var headerView: some View {
        HStack {
            Button(action: { showProfileSheet = true }) {
                HStack(spacing: 12) {
                    ZStack { Circle().fill(Color.white.opacity(0.1)).frame(width: 44, height: 44); Image(systemName: "person.fill").font(.system(size: 20)).foregroundStyle(Color.neonGreen) }
                    VStack(alignment: .leading, spacing: 2) { Text("COACH AI").font(.caption).tracking(2).foregroundStyle(Color.neonGreen); Text(userProfiles.first?.name.uppercased() ?? "ATLETA").font(.system(size: 20, weight: .bold)).foregroundStyle(.white) }
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: { showImportSheet = true }) { Circle().fill(Color.white.opacity(0.1)).frame(width: 44, height: 44).overlay(Image(systemName: importedContext.isEmpty ? "paperclip" : "doc.fill").foregroundStyle(importedContext.isEmpty ? .white : Color.neonGreen)) }
                HStack(spacing: 6) { Circle().fill(audioManager.isListening ? Color.red : Color.green).frame(width: 8, height: 8); Text(audioManager.isListening ? "OUVINDO" : "ONLINE").font(.caption2.bold()).foregroundStyle(.white) }
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Color.white.opacity(0.1)).cornerRadius(20)
            }
        }
        .padding(.horizontal, 24)
    }
    
    var contextBanner: some View {
        HStack { Image(systemName: "doc.text.fill").font(.caption); Text("Contexto importado ativo").font(.caption); Spacer(); Button("Limpar") { importedContext = "" }.font(.caption.bold()) }
            .foregroundStyle(Color.neonGreen).padding(.horizontal, 12).padding(.vertical, 8).background(Color.neonGreen.opacity(0.1)).cornerRadius(8).padding(.horizontal, 24)
    }
    
    var loadingView: some View { VStack(spacing: 20) { ProgressView().tint(.neonGreen).scaleEffect(1.5); Text("GERANDO PLANO COMPLETO...").font(.caption).tracking(2).foregroundStyle(.gray) } }
    
    func errorView(message: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.red)
            Text("ALERTA DO SISTEMA").font(.caption.bold()).foregroundStyle(.red)
            Text(message).font(.body).foregroundStyle(.white).multilineTextAlignment(.center).padding().background(Color.red.opacity(0.1)).cornerRadius(12).padding(.horizontal)
            Button("Tentar Novamente") { aiService.errorMessage = nil }.buttonStyle(.bordered).tint(.white)
        }
    }
    
    var emptyStateView: some View { VStack(spacing: 16) { Text("SEM TREINO ATIVO").font(.system(size: 24, weight: .heavy)).foregroundStyle(Color.white.opacity(0.1)); Text("Peça: 'Quero um plano de 2 meses para meia maratona'.").font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center).frame(maxWidth: 280) } }
    
    var transcriptionView: some View { Text(audioManager.transcribedText).font(.body).foregroundStyle(.white).multilineTextAlignment(.center).padding().background(Color.black.opacity(0.8)).cornerRadius(12).padding(.horizontal) }
    
    var micButton: some View {
        Button(action: handleMicAction) {
            ZStack {
                // ✅ Animação de pulso quando ouvindo
                if audioManager.isListening { 
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .frame(width: 110, height: 110)
                        .scaleEffect(audioManager.isListening ? 1.3 : 1.0)
                        .opacity(audioManager.isListening ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.2)
                            .repeatForever(autoreverses: false),
                            value: audioManager.isListening
                        )
                }
                
                Circle()
                    .fill(audioManager.isListening ? Color.red : Color.neonGreen)
                    .frame(width: 80, height: 80)
                    .shadow(
                        color: (audioManager.isListening ? Color.red : Color.neonGreen).opacity(0.4),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                
                // ✅ Ícone animado
                Image(systemName: audioManager.isListening ? "stop.fill" : "mic.fill")
                    .font(.title)
                    .foregroundStyle(audioManager.isListening ? .white : .black)
                    .scaleEffect(audioManager.isListening ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: audioManager.isListening)
            }
        }
        .padding(.bottom, 40)
    }
    
    func handleMicAction() {
        if audioManager.isListening { audioManager.stopRecording(); generateWorkout() }
        else { withAnimation { aiService.suggestedWorkouts = []; aiService.suggestedRoadmap = [] }; audioManager.startRecording() }
    }
    
    // MARK: - Geração de Treino Corrigida
    func generateWorkout() {
        // 🔥 FORÇA ATUALIZAÇÃO DO HEALTH PRIMEIRO
        print("🔄 Atualizando dados do Health...")
        isLoadingHealthData = true
        hkManager.fetchAllData()
        
        // Aguarda 2 segundos para garantir que os dados foram carregados
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isLoadingHealthData = false
            self.continueGenerateWorkout()
        }
    }
    
    private func continueGenerateWorkout() {
        // 1. Perfil
        let profile = userProfiles.first.map {
            AIUserProfile(name: $0.name, experienceLevel: $0.experienceLevel, goal: $0.mainGoal, daysPerWeek: $0.weeklyFrequency, currentDistance: hkManager.weeklyDistance)
        } ?? AIUserProfile(name: "Atleta", experienceLevel: "Iniciante", goal: "Saúde", daysPerWeek: 3, currentDistance: 0)
        
        // 2. CONTEXTO DE SAÚDE (Correção Principal)
        // Montamos um resumo legível para a IA entender seu estado atual
        var healthStats = "Resumo HealthKit (Últimos 7 dias):\n"
        healthStats += "- Volume Semanal Total: \(String(format: "%.1f", hkManager.weeklyDistance)) km\n"
        
        // 🆕 MÉTRICAS AVANÇADAS
        if let vo2 = hkManager.vo2Max {
            healthStats += "- VO2Max: \(String(format: "%.1f", vo2)) ml/kg/min\n"
            print("✅ VO2Max incluído no contexto: \(vo2)")
        } else {
            print("⚠️ VO2Max NÃO DISPONÍVEL")
        }
        if let rhr = hkManager.restingHeartRate {
            healthStats += "- FC Repouso: \(String(format: "%.0f", rhr)) bpm\n"
            print("✅ FC Repouso incluída: \(rhr)")
        } else {
            print("⚠️ FC Repouso NÃO DISPONÍVEL")
        }
        if let avgPace = hkManager.calculateAveragePace() {
            healthStats += "- Pace Médio: \(avgPace) /km (últimos treinos)\n"
            print("✅ Pace real incluído: \(avgPace)")
        } else {
            print("⚠️ Pace real NÃO DISPONÍVEL")
        }
        
        print("📄 CONTEXTO COMPLETO:")
        print(healthStats)
        
        healthStats += "- Histórico Diário:\n"
        
        let sortedHistory = hkManager.dailyHistory.sorted(by: { $0.date > $1.date })
        if sortedHistory.isEmpty {
            healthStats += "  (Sem corridas recentes registradas)\n"
        } else {
            for activity in sortedHistory.prefix(7) {
                let dist = String(format: "%.1f", activity.distance)
                healthStats += "  - \(activity.day): \(dist) km\n"
            }
        }
        
        // 3. Texto do Usuário
        let finalText = "\(importedContext) \n \(audioManager.transcribedText)"
        
        // 4. Buscar Treinos Existentes (Anti-Duplicação)
        var existingPlans: [DailyPlan] = []
        if let data = UserDefaults.standard.data(forKey: "saved_workouts"),
           let saved = try? JSONDecoder().decode([DailyPlan].self, from: data) {
            existingPlans = saved
        }
        
        // 5. Chamada com healthContext
        aiService.generateWeekPlan(
            for: profile,
            healthContext: healthStats,
            instruction: finalText,
            existingPlans: existingPlans
        )
    }
}
