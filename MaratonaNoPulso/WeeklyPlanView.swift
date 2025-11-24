//
//  WeeklyPlanView.swift
//  MaratonaNoPulso
//
//  Created by Phelipe de Oliveira Xavier on 24/11/25.
//

import SwiftUI
import UIKit

struct WeeklyPlanView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var aiService = AIService()
    @StateObject private var workoutKitManager = WorkoutKitManager()
    @StateObject private var phoneSessionManager = PhoneSessionManager()
    
    @State private var isLoading = false
    @State private var generatedPlan: WeeklyTrainingPlan?
    @State private var resultMessage: String = ""
    @State private var currentStep: PlanStep = .listening
    @State private var selectedWorkout: DailyWorkout?
    @State private var showShareSheet = false
    @State private var shareItems: [URL] = []
    
    enum PlanStep {
        case listening, processing, preview, exporting, result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Main Content
                    mainContent
                    
                    Spacer()
                    
                    // Action Button
                    if currentStep != .exporting {
                        actionButton
                    }
                }
                .padding()
            }
            .navigationTitle("Maratona no Pulso")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            Task {
                _ = await workoutKitManager.requestAuthorization()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(activityItems: shareItems)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: currentStep == .preview ? "calendar" : "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
            
            Text(headerTitle)
                .font(.headline)
                .foregroundColor(.gray)
        }
        .padding(.top)
    }
    
    private var headerTitle: String {
        switch currentStep {
        case .listening: return "Fale seu objetivo"
        case .processing: return "Gerando plano..."
        case .preview: return "Seu Plano Semanal"
        case .exporting: return "Criando workouts..."
        case .result: return "Concluído"
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        switch currentStep {
        case .listening:
            listeningView
        case .processing:
            processingView
        case .preview:
            if let plan = generatedPlan {
                weeklyPlanPreview(plan)
            }
        case .exporting:
            exportingView
        case .result:
            resultView
        }
    }
    
    // MARK: - Listening View
    
    private var listeningView: some View {
        VStack(spacing: 16) {
            if audioManager.isListening {
                // Animação de gravação
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red)
                            .frame(width: 4, height: CGFloat.random(in: 10...30))
                    }
                }
                .frame(height: 30)
                
                Text("Ouvindo...")
                    .foregroundColor(.red)
            }
            
            if !audioManager.transcribedText.isEmpty {
                Text("\"\(audioManager.transcribedText)\"")
                    .font(.body)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(12)
            }
            
            Text("Exemplo: \"Crie um plano de 1 semana para eu correr 3km\"")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("🤖 AI está criando seu plano...")
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Exporting View
    
    private var exportingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: workoutKitManager.exportProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .frame(width: 200)
            
            Text("📦 Criando workouts...")
                .foregroundColor(.white)
            
            Text("\(Int(workoutKitManager.exportProgress * 100))% concluído")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Weekly Plan Preview
    
    private func weeklyPlanPreview(_ plan: WeeklyTrainingPlan) -> some View {
        VStack(spacing: 16) {
            // Plan Header
            VStack(spacing: 4) {
                Text(plan.plan_name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(plan.goal_description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Workouts List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(plan.workouts) { workout in
                        WorkoutDayCard(workout: workout)
                            .onTapGesture {
                                selectedWorkout = workout
                            }
                    }
                }
            }
            .frame(maxHeight: 400)
            
            // Summary
            HStack {
                Label("\(plan.workouts.filter { !$0.is_rest_day }.count) treinos", systemImage: "figure.run")
                Spacer()
                Label("\(plan.total_days) dias", systemImage: "calendar")
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailSheet(workout: workout)
        }
    }
    
    // MARK: - Result View
    
    private var resultView: some View {
        VStack(spacing: 16) {
            Text(resultMessage.contains("✅") ? "✅" : "❌")
                .font(.system(size: 60))
            
            Text(resultMessage)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Botão para tentar agendar workouts
            if currentStep == .result {
                VStack(spacing: 12) {
                    Button(action: {
                        scheduleWorkouts()
                    }) {
                        HStack {
                            Image(systemName: "applewatch")
                            Text("Tentar Agendar no Apple Watch")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Text("Se os workouts não apareceram, tente agendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
            }
        }
    }
    
    // MARK: - Action Button
    
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
        case .exporting: return .gray
        case .result: return .blue
        }
    }
    
    private var buttonIcon: String {
        switch currentStep {
        case .listening: return audioManager.isListening ? "stop.fill" : "mic.fill"
        case .processing: return "hourglass"
        case .preview: return "applewatch"
        case .exporting: return "hourglass"
        case .result: return "arrow.clockwise"
        }
    }
    
    // MARK: - Actions
    
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
            exportWorkoutFiles()
            
        case .exporting:
            break
            
        case .result:
            resetFlow()
        }
    }
    
    private func processAudio() {
        guard !audioManager.transcribedText.isEmpty else {
            resultMessage = "❌ Não consegui entender. Tente novamente."
            currentStep = .result
            return
        }
        
        currentStep = .processing
        isLoading = true
        
        Task {
            if let plan = await aiService.generateWeeklyPlan(from: audioManager.transcribedText) {
                await MainActor.run {
                    if let moreInfo = plan.needsMoreInfo {
                        resultMessage = "🤔 \(moreInfo)"
                        currentStep = .result
                    } else {
                        generatedPlan = plan
                        currentStep = .preview
                    }
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    resultMessage = "❌ Erro ao gerar plano"
                    currentStep = .result
                    isLoading = false
                }
            }
        }
    }
    
    private func exportWorkoutFiles() {
        guard let plan = generatedPlan else { return }
        
        currentStep = .exporting
        
        Task {
            // Tenta primeiro exportar como workouts
            let success = await workoutKitManager.exportWeeklyPlan(plan)
            
            // Se não funcionar, tenta agendar
            if !success {
                let scheduled = await workoutKitManager.scheduleWorkouts(plan)
                await MainActor.run {
                    if scheduled {
                        let workoutCount = plan.workouts.filter { !$0.is_rest_day }.count
                        resultMessage = "✅ \(workoutCount) treinos agendados!\n\nVerifique no app Fitness/Workout do Apple Watch."
                    } else {
                        resultMessage = "❌ Erro ao criar treinos\n\n\(workoutKitManager.lastError)\n\nVerifique as permissões do HealthKit."
                    }
                    currentStep = .result
                }
            } else {
                await MainActor.run {
                    let workoutCount = plan.workouts.filter { !$0.is_rest_day }.count
                    resultMessage = "✅ \(workoutCount) workouts criados!\n\nVerifique no app Fitness/Workout.\n\nSe não aparecerem, tente o botão abaixo."
                    currentStep = .result
                }
            }
        }
    }
    
    private func scheduleWorkouts() {
        guard let plan = generatedPlan else { return }
        
        currentStep = .exporting
        
        Task {
            let scheduled = await workoutKitManager.scheduleWorkouts(plan)
            
            await MainActor.run {
                if scheduled {
                    let workoutCount = plan.workouts.filter { !$0.is_rest_day }.count
                    resultMessage = "✅ \(workoutCount) treinos agendados!\n\nVerifique no app Fitness/Workout do Apple Watch."
                } else {
                    resultMessage = "❌ Erro ao agendar treinos\n\n\(workoutKitManager.lastError)"
                }
                currentStep = .result
            }
        }
    }
    
    private func resetFlow() {
        currentStep = .listening
        resultMessage = ""
        generatedPlan = nil
        audioManager.transcribedText = ""
        shareItems = []
        
        // Limpar workouts
        Task {
            await workoutKitManager.clearExportedFiles()
        }
    }
}

// MARK: - Workout Day Card

struct WorkoutDayCard: View {
    let workout: DailyWorkout
    
    var body: some View {
        HStack(spacing: 12) {
            // Day indicator
            VStack {
                Text("DIA")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("\(workout.day)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(width: 50)
            
            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: workout.workout_type.systemImage)
                        .foregroundColor(workout.is_rest_day ? .gray : .green)
                    
                    Text(workout.workout_name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                if !workout.is_rest_day {
                    HStack(spacing: 12) {
                        if let distance = workout.distance_km {
                            Label("\(String(format: "%.1f", distance))km", systemImage: "ruler")
                        }
                        Label("\(workout.duration_minutes)min", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                } else {
                    Text(workout.instructions)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(workout.is_rest_day ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
        )
    }
}

// MARK: - Workout Detail Sheet

struct WorkoutDetailSheet: View {
    let workout: DailyWorkout
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: workout.workout_type.systemImage)
                                .font(.title)
                                .foregroundColor(.green)
                            
                            Text(workout.workout_name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text(workout.workout_type.displayName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Stats
                    if !workout.is_rest_day {
                        HStack(spacing: 20) {
                            StatItem(title: "Duração", value: "\(workout.duration_minutes)min", icon: "clock")
                            
                            if let distance = workout.distance_km {
                                StatItem(title: "Distância", value: "\(String(format: "%.1f", distance))km", icon: "ruler")
                            }
                            
                            if let pace = workout.pace_min_per_km {
                                StatItem(title: "Pace", value: "\(String(format: "%.1f", pace))'/km", icon: "speedometer")
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instruções")
                            .font(.headline)
                        
                        Text(workout.instructions)
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    
                    // Segments
                    if let segments = workout.segments, !segments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Estrutura do Treino")
                                .font(.headline)
                            
                            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                                SegmentRow(segment: segment, index: index + 1)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dia \(workout.day)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SegmentRow: View {
    let segment: WorkoutSegment
    let index: Int
    
    var body: some View {
        HStack {
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(colorFor(segment.type)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.description)
                    .font(.subheadline)
                
                HStack {
                    Text("\(segment.duration_minutes)min")
                    Text("•")
                    Text(segment.intensity.capitalized)
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func colorFor(_ type: String) -> Color {
        switch type.lowercased() {
        case "warmup", "warm_up": return .orange
        case "cooldown", "cool_down": return .blue
        case "main": return .green
        default: return .purple
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    WeeklyPlanView()
}
