import SwiftUI
import WorkoutKit
import SwiftData

struct LibraryView: View {
    @State private var savedWorkouts: [DailyPlan] = []
    @State private var searchText: String = ""
    
    // 🗂️ Filtra por tipo de container
    var trainingPlans: [DailyPlan] {
        savedWorkouts.filter { $0.activityType == "plan_container" && !$0.isArchived }
    }
    
    var looseWorkouts: [DailyPlan] {
        // Treinos avulsos (sem pai) e que não são containers
        savedWorkouts.filter { 
            $0.parentPlanId == nil && 
            $0.activityType != "plan_container" && 
            $0.activityType != "week_container" &&
            !$0.isArchived
        }
    }
    
    var archivedItems: [DailyPlan] {
        savedWorkouts.filter { $0.isArchived }
    }
    
    var filteredPlans: [DailyPlan] {
        if searchText.isEmpty { return trainingPlans }
        return trainingPlans.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if savedWorkouts.isEmpty {
                    ContentUnavailableView(
                        "Biblioteca Vazia",
                        systemImage: "dumbbell",
                        description: Text("Gere treinos com o Coach AI para começar.")
                    )
                } else {
                    List {
                        // SEÇÃO 1: MEUS PLANOS (Hierárquicos)
                        if !filteredPlans.isEmpty {
                            Section(header: Text("MEUS PLANOS").font(.caption).bold().tracking(2).foregroundStyle(.neonGreen)) {
                                ForEach(filteredPlans) { plan in
                                    NavigationLink(destination: PlanDetailView(
                                        plan: plan,
                                        allWorkouts: $savedWorkouts,
                                        onDelete: deletePlan
                                    )) {
                                        PlanRow(plan: plan, totalWorkouts: countWorkoutsInPlan(plan))
                                    }
                                    .listRowBackground(Color.white.opacity(0.05))
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            deletePlan(plan)
                                        } label: {
                                            Label("Apagar Plano", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        
                        // SEÇÃO 2: TREINOS AVULSOS (Legado)
                        if !looseWorkouts.isEmpty {
                            Section(header: Text("TREINOS AVULSOS").font(.caption).foregroundStyle(.gray)) {
                                ForEach(looseWorkouts) { workout in
                                    if let index = savedWorkouts.firstIndex(where: { $0.id == workout.id }) {
                                        NavigationLink(destination: WorkoutEditorView(workout: $savedWorkouts[index])) {
                                            WorkoutRow(workout: workout)
                                        }
                                        .listRowBackground(Color.white.opacity(0.05))
                                        .swipeActions {
                                            Button(role: .destructive) {
                                                deleteWorkout(workout.id)
                                            } label: {
                                                Label("Apagar", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // SEÇÃO 3: ARQUIVADOS
                        if !archivedItems.isEmpty {
                            Section(header: Text("ARQUIVADOS").font(.caption).foregroundStyle(.gray)) {
                                ForEach(archivedItems) { item in
                                    HStack {
                                        Text(item.title)
                                            .strikethrough()
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        Button("Restaurar") {
                                            toggleArchive(item.id)
                                        }
                                        .font(.caption).bold()
                                        .foregroundStyle(.neonGreen)
                                    }
                                    .listRowBackground(Color.black.opacity(0.3))
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            deleteWorkout(item.id)
                                        } label: {
                                            Label("Apagar", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Buscar planos...")
                }
            }
            .navigationTitle("Biblioteca")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear(perform: loadWorkouts)
        }
    }
    
    // MARK: - Funções de Dados
    
    func loadWorkouts() {
        if let data = UserDefaults.standard.data(forKey: "saved_workouts"),
           let decoded = try? JSONDecoder().decode([DailyPlan].self, from: data) {
            savedWorkouts = decoded
            print("📚 Biblioteca carregada: \(savedWorkouts.count) itens")
            print("   - Planos: \(trainingPlans.count)")
            print("   - Avulsos: \(looseWorkouts.count)")
        }
    }
    
    func countWorkoutsInPlan(_ plan: DailyPlan) -> Int {
        // Conta semanas
        let weekIds = savedWorkouts.filter { $0.parentPlanId == plan.id }.map { $0.id }
        // Conta treinos nas semanas
        return savedWorkouts.filter { weekIds.contains($0.parentPlanId ?? UUID()) }.count
    }
    
    func deletePlan(_ plan: DailyPlan) {
        withAnimation {
            print("🗑️ Apagando plano: \(plan.title)")
            
            // 1. Encontra IDs das semanas filhas
            let weekIds = savedWorkouts.filter { $0.parentPlanId == plan.id }.map { $0.id }
            print("   - Semanas encontradas: \(weekIds.count)")
            
            // 2. Apaga treinos das semanas
            savedWorkouts.removeAll { workout in
                if let parent = workout.parentPlanId {
                    return weekIds.contains(parent)
                }
                return false
            }
            
            // 3. Apaga as semanas
            savedWorkouts.removeAll { $0.parentPlanId == plan.id }
            
            // 4. Apaga o plano pai
            savedWorkouts.removeAll { $0.id == plan.id }
            
            print("✅ Plano apagado. Restam: \(savedWorkouts.count) itens")
            saveToDisk()
        }
    }
    
    func deleteWorkout(_ id: UUID) {
        withAnimation {
            savedWorkouts.removeAll { $0.id == id }
            saveToDisk()
        }
    }
    
    func toggleArchive(_ id: UUID) {
        withAnimation {
            if let index = savedWorkouts.firstIndex(where: { $0.id == id }) {
                savedWorkouts[index].isArchived.toggle()
                saveToDisk()
            }
        }
    }
    
    func saveToDisk() {
        if let encoded = try? JSONEncoder().encode(savedWorkouts) {
            UserDefaults.standard.set(encoded, forKey: "saved_workouts")
            print("💾 Salvou \(savedWorkouts.count) itens")
        }
    }
}

// MARK: - 📂 Visão Detalhada do Plano (Nível 2: Semanas)
struct PlanDetailView: View {
    let plan: DailyPlan
    @Binding var allWorkouts: [DailyPlan]
    var onDelete: (DailyPlan) -> Void
    
    // Filtra semanas deste plano
    var weeks: [DailyPlan] {
        allWorkouts
            .filter { $0.parentPlanId == plan.id && $0.activityType == "week_container" }
            .sorted { ($0.weekNumber ?? 0) < ($1.weekNumber ?? 0) }
    }
    
    var totalWorkouts: Int {
        let weekIds = weeks.map { $0.id }
        return allWorkouts.filter { weekIds.contains($0.parentPlanId ?? UUID()) }.count
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            List {
                // Header do Plano
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(plan.description)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        HStack {
                            Label("\(weeks.count) Semanas", systemImage: "calendar")
                                .font(.caption)
                            Spacer()
                            Label("\(totalWorkouts) Treinos", systemImage: "figure.run")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.neonGreen)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                
                // Lista de Semanas (Expansível)
                ForEach(weeks) { week in
                    DisclosureGroup(
                        content: {
                            WeekWorkoutsList(weekId: week.id, allWorkouts: $allWorkouts)
                        },
                        label: {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(Color.neonGreen)
                                Text(week.title)
                                    .font(.headline).bold()
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(week.description)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                    )
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(plan.title)
        .toolbar {
            Button("Apagar Plano", role: .destructive) {
                onDelete(plan)
            }
        }
    }
}

// MARK: - 📅 Lista de Treinos da Semana (Nível 3)
struct WeekWorkoutsList: View {
    let weekId: UUID
    @Binding var allWorkouts: [DailyPlan]
    
    var workouts: [DailyPlan] {
        allWorkouts
            .filter { $0.parentPlanId == weekId }
            .sorted { $0.day < $1.day }
    }
    
    var body: some View {
        ForEach(workouts) { workout in
            if let index = allWorkouts.firstIndex(where: { $0.id == workout.id }) {
                NavigationLink(destination: WorkoutEditorView(workout: $allWorkouts[index])) {
                    WorkoutRow(workout: workout)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        allWorkouts.removeAll { $0.id == workout.id }
                        saveToDisk()
                    } label: {
                        Label("Apagar", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    func saveToDisk() {
        if let encoded = try? JSONEncoder().encode(allWorkouts) {
            UserDefaults.standard.set(encoded, forKey: "saved_workouts")
        }
    }
}

// MARK: - 🎨 Componentes Visuais
struct PlanRow: View {
    let plan: DailyPlan
    let totalWorkouts: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.neonGreen.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(Color.neonGreen)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.headline).bold()
                    .foregroundStyle(.white)
                Text("\(totalWorkouts) treinos")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
                .font(.caption)
        }
        .padding(.vertical, 6)
    }
}

struct WorkoutRow: View {
    let workout: DailyPlan
    
    var icon: String {
        switch workout.activityType {
        case "strength": return "dumbbell.fill"
        case "rest": return "bed.double.fill"
        default: return "figure.run"
        }
    }
    
    var color: Color {
        switch workout.activityType {
        case "strength": return .orange
        case "rest": return .blue
        default: return .neonGreen
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 36, height: 36)
                
                if workout.isCompleted {
                    Circle().fill(Color.neonGreen).frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.caption).bold()
                        .foregroundStyle(.black)
                } else {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.subheadline).bold()
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    Text(workout.day)
                        .font(.caption2).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.2))
                        .foregroundStyle(color)
                        .cornerRadius(4)
                    
                    if let phase = workout.cyclePhase {
                        Text(phase)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    
                    // 🏋️ Indicador de treino de força
                    if workout.activityType == "strength",
                       let strengthParams = workout.strengthParams {
                        Text("\(strengthParams.sets ?? 0)×\(strengthParams.reps ?? "0")")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - EDITOR DE TREINO REFATORADO
struct WorkoutEditorView: View {
    @Binding var workout: DailyPlan
    @State private var segments: [WorkoutSegment] = []
    
    @StateObject private var workoutManager = WorkoutKitManager.shared
    @StateObject private var aiService = AIService.shared  // 🔥 Usando singleton
    @StateObject private var hkManager = HealthKitManager.shared
    
    @Query private var userProfiles: [UserProfile]
    
    @State private var showWorkoutPreview = false
    @State private var appleWorkoutPlan: WorkoutKit.WorkoutPlan?
    @State private var isGeneratingSegments = false
    
    struct SegmentSelection: Identifiable { let id: UUID }
    @State private var selectedSegment: SegmentSelection?
    
    var body: some View {
        Form {
            headerSection
            actionsSection
            structureSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(workout.title)
        .onAppear(perform: load)
        .onDisappear(perform: save)
        .onChange(of: aiService.generatedSegments) { _, new in
            if let s = new {
                segments = s
                isGeneratingSegments = false
                save()
            }
        }
        .sheet(item: $selectedSegment) { selection in
            if let index = segments.firstIndex(where: { $0.id == selection.id }) {
                NavigationStack { AdvancedSegmentEditor(segment: $segments[index]) }
                    .presentationDetents([.medium])
            }
        }
        .workoutPreview(appleWorkoutPlan ?? WorkoutKitManager.emptyPlan, isPresented: $showWorkoutPreview)
    }
    
    // MARK: - Subviews do Form
    
    var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ContextChip(icon: workout.sourceIcon ?? "cpu", text: workout.sourceLabel ?? "IA", color: .neonGreen)
                    if let difficulty = workout.safetyBadge { ContextChip(icon: "waveform.path.ecg", text: difficulty, color: .orange) }
                }
                if let tips = workout.coachTips {
                    Text(tips).font(.caption).foregroundStyle(.gray).padding(8).background(Color.white.opacity(0.05)).cornerRadius(8)
                }
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
    }
    
    var actionsSection: some View {
        Section("Ações") {
            if segments.isEmpty {
                Button(action: generateStructure) {
                    HStack {
                        if isGeneratingSegments {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("Gerar Estrutura Técnica")
                        }
                    }
                    .foregroundStyle(.black).frame(maxWidth: .infinity).padding(8).background(Color.neonGreen).cornerRadius(8)
                }
                .disabled(isGeneratingSegments)
                .listRowBackground(Color.clear)
            } else {
                Button(action: { Task { await exportToWatch() } }) {
                    HStack { Image(systemName: "applewatch"); Text("Enviar p/ Watch") }
                        .foregroundStyle(.black).frame(maxWidth: .infinity).padding(8).background(Color.neonGreen).cornerRadius(8)
                }
                .listRowBackground(Color.clear)
            }
        }
    }
    
    var structureSection: some View {
        Section("Estrutura") {
            if segments.isEmpty {
                Text("Sem estrutura definida.").font(.caption).foregroundStyle(.gray)
            } else {
                List {
                    ForEach(segments) { s in
                        SegmentRowView(segment: s)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedSegment = SegmentSelection(id: s.id) }
                    }
                    .onDelete { segments.remove(atOffsets: $0); save() }
                    .onMove { segments.move(fromOffsets: $0, toOffset: $1); save() }
                }
            }
            Button(action: addSegment) { Label("Adicionar Bloco Manualmente", systemImage: "plus.circle.fill").foregroundStyle(Color.neonGreen) }
                .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Logic
    
    func generateStructure() {
        let instr = workout.rawInstructionText ?? workout.description
        let title = workout.title
        let phase = workout.cyclePhase ?? "Geral"
        
        isGeneratingSegments = true
        
        // 🔥 CORREÇÃO CRÍTICA: Usar perfil REAL e contexto do Health
        let profile: AIUserProfile
        if let userProfile = userProfiles.first {
            profile = AIUserProfile(
                name: userProfile.name,
                experienceLevel: userProfile.experienceLevel,
                goal: userProfile.mainGoal,
                daysPerWeek: userProfile.weeklyFrequency,
                currentDistance: hkManager.weeklyDistance
            )
        } else {
            // Fallback se não tiver perfil (não deveria acontecer)
            profile = AIUserProfile(
                name: "Atleta",
                experienceLevel: "Intermediário",
                goal: "Fitness",
                daysPerWeek: 3,
                currentDistance: hkManager.weeklyDistance
            )
        }
        
        // 🔥 IMPORTANTE: generateDetailedSegments vai REUTILIZAR o athleteContext
        // que foi calculado durante generateWeekPlan. Se não existir, vai criar um fallback.
        // Mas o ideal é que o contexto já exista!
        
        aiService.generateDetailedSegments(for: instr, title: title, phase: phase, user: profile)
    }
    
    func load() { if let json = workout.structure, let data = json.data(using: .utf8), let decoded = try? JSONDecoder().decode([WorkoutSegment].self, from: data) { segments = decoded } }
    func save() { if let data = try? JSONEncoder().encode(segments), let str = String(data: data, encoding: .utf8) { workout.structure = str }; saveGlobal() }
    func saveGlobal() {
        if let data = UserDefaults.standard.data(forKey: "saved_workouts"), var all = try? JSONDecoder().decode([DailyPlan].self, from: data) {
            if let idx = all.firstIndex(where: { $0.id == workout.id }) { all[idx] = workout; if let enc = try? JSONEncoder().encode(all) { UserDefaults.standard.set(enc, forKey: "saved_workouts") } }
        }
    }
    func exportToWatch() async { save(); if let p = await workoutManager.createCustomWorkout(from: workout) { DispatchQueue.main.async { self.appleWorkoutPlan = WorkoutKit.WorkoutPlan(.custom(p)); self.showWorkoutPreview = true } } }
    func addSegment() { segments.append(WorkoutSegment(role: .work, goalType: .time, durationMinutes: 5)); save() }
    func ContextChip(icon: String, text: String, color: Color) -> some View { HStack(spacing: 4) { Image(systemName: icon); Text(text.uppercased()).font(.caption2).bold() }.padding(6).background(color.opacity(0.2)).foregroundStyle(color).cornerRadius(4) }
}

// MARK: - AdvancedSegmentEditor
struct AdvancedSegmentEditor: View {
    @Binding var segment: WorkoutSegment; @Environment(\.dismiss) var dismiss
    var body: some View {
        Form {
            Section("Função") { Picker("Tipo", selection: $segment.role) { ForEach(SegmentRole.allCases) { role in Text(role.rawValue).tag(role) } }.pickerStyle(.menu) }
            Section("Meta") {
                Picker("Tipo", selection: $segment.goalType) { ForEach(GoalType.allCases) { type in Text(type.rawValue).tag(type) } }.pickerStyle(.segmented)
                if segment.goalType == .time { HStack { Text("Duração"); Spacer(); TextField("Min", value: $segment.durationMinutes, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text("min") } }
                else if segment.goalType == .distance { HStack { Text("Distância"); Spacer(); TextField("Km", value: $segment.distanceKm, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text("km") } }
            }
            Section("Alertas") {
                HStack { Text("Pace Min"); Spacer(); TextField("Ex: 4:30", text: Binding(get: { segment.targetPaceMin ?? "" }, set: { segment.targetPaceMin = $0.isEmpty ? nil : $0 })).multilineTextAlignment(.trailing) }
                HStack { Text("Pace Máx"); Spacer(); TextField("Ex: 5:00", text: Binding(get: { segment.targetPaceMax ?? "" }, set: { segment.targetPaceMax = $0.isEmpty ? nil : $0 })).multilineTextAlignment(.trailing) }
            }
            if segment.role == .work || segment.role == .recovery { Section("Repetições") { Stepper("Repetir: \(segment.reps ?? 1)x", value: Binding(get: { segment.reps ?? 1 }, set: { segment.reps = $0 }), in: 1...20) } }
            Button("Concluir") { dismiss() }
        }
        .navigationTitle("Configurar Bloco")
    }
}

// MARK: - SegmentRowView
struct SegmentRowView: View {
    let segment: WorkoutSegment
    var iconName: String { switch segment.role { case .warmup: return "figure.walk"; case .work: return "figure.run"; case .recovery: return "lungs.fill"; case .cooldown: return "figure.cooldown" } }
    var color: Color { switch segment.role { case .warmup, .cooldown: return .blue; case .work: return .neonGreen; case .recovery: return .orange } }
    var body: some View {
        HStack {
            Image(systemName: iconName).foregroundStyle(color).frame(width: 30)
            VStack(alignment: .leading) { Text(segment.role.rawValue).font(.headline).foregroundStyle(.white); Text(segment.summary).font(.caption).foregroundStyle(.gray) }
            Spacer()
            if let pace = segment.targetPaceMin { Text("@ \(pace)").font(.caption.bold()).padding(6).background(Color.white.opacity(0.1)).cornerRadius(6).foregroundStyle(.white) }
        }
        .padding(.vertical, 4)
    }
}
