import SwiftUI
import HealthKit

struct PostWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    var workout: HKWorkout
    
    @StateObject private var aiService = AIService.shared  // 🔥 Usando singleton
    
    // Inputs
    @State private var rpeSlider: Double = 5.0
    @State private var painSelected: String = "Nenhuma"
    
    let painOptions = ["Nenhuma", "Leve (Muscular)", "Joelho", "Canela", "Pé", "Aguda"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        WorkoutHeader
                        
                        VStack(alignment: .leading, spacing: 20) {
                            Text("ANÁLISE SUBJETIVA").font(.caption).bold().tracking(2).foregroundStyle(.gray)
                            
                            VStack(alignment: .leading) {
                                HStack { Text("Esforço Percebido (RPE)"); Spacer(); Text("\(Int(rpeSlider))/10").foregroundStyle(rpeColor).bold() }
                                Slider(value: $rpeSlider, in: 1...10, step: 1).tint(rpeColor)
                            }.padding().glass()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Monitor de Dor").font(.subheadline).bold()
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(painOptions, id: \.self) { pain in
                                            PainChip(text: pain, isSelected: painSelected == pain)
                                                .onTapGesture { painSelected = pain }
                                        }
                                    }
                                }
                            }.padding().glass()
                        }
                        .foregroundStyle(.white)
                        
                        // Estado: Loading / Erro / Sucesso / Botão
                        if aiService.isLoading {
                            VStack { ProgressView().tint(.neonGreen); Text("Analisando Biometria...").font(.caption).foregroundStyle(.gray) }
                                .padding().glass()
                        }
                        else if let error = aiService.errorMessage {
                            VStack {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                                Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                                Button("Tentar Novamente") { processWorkout() }.font(.caption.bold())
                            }.padding().glass()
                        }
                        else if let analysis = aiService.postWorkoutAnalysis {
                            ResultCard(analysis: analysis)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        else {
                            Button(action: processWorkout) {
                                HStack { Image(systemName: "brain.head.profile"); Text("PROCESSAR COM IA") }
                                    .font(.headline.bold()).foregroundStyle(.black)
                                    .frame(maxWidth: .infinity).frame(height: 56)
                                    .background(Color.neonGreen).cornerRadius(16)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Workout Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Fechar") { dismiss() }.tint(.white) } }
        }
    }
    
    // MARK: - Components
    var WorkoutHeader: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text(workout.workoutActivityType == .running ? "CORRIDA" : "TREINO").font(.caption).bold().foregroundStyle(Color.neonGreen)
                    Text(workout.startDate.formatted(date: .abbreviated, time: .shortened)).font(.title3).bold().foregroundStyle(.white)
                }
                Spacer(); Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(Color.neonGreen)
            }
            HStack(spacing: 15) {
                StatBox(
                    value: String(format: "%.2f", workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!)?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0),
                    unit: "km"
                )
                StatBox(value: durationString(workout.duration), unit: "tempo")
                StatBox(
                    value: String(format: "%.0f", workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0),
                    unit: "kcal"
                )
            }
        }.padding().glass()
    }
    
    func StatBox(value: String, unit: String) -> some View {
        VStack { Text(value).font(.title2).bold().foregroundStyle(.white); Text(unit.uppercased()).font(.caption2).bold().foregroundStyle(.gray) }
            .frame(maxWidth: .infinity).padding(.vertical, 10).background(Color.white.opacity(0.05)).cornerRadius(10)
    }
    
    func PainChip(text: String, isSelected: Bool) -> some View {
        Text(text).font(.caption.bold()).padding(.horizontal, 16).padding(.vertical, 8)
            .background(isSelected ? (text == "Nenhuma" ? Color.green : Color.red) : Color.white.opacity(0.1))
            .foregroundStyle(.white).cornerRadius(20)
    }
    
    func ResultCard(analysis: PostWorkoutAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Image(systemName: "sparkles"); Text("ANÁLISE DO COACH").font(.headline) }.foregroundStyle(Color.neonGreen)
            
            Text(analysis.analysisSummary).foregroundStyle(.white).font(.body)
            
            HStack {
                VStack(alignment: .leading) { Text("Recuperação").font(.caption).foregroundStyle(.gray); Text("\(analysis.recoveryScore)%").bold().foregroundStyle(.blue) }
                Spacer()
                VStack(alignment: .trailing) { Text("Ação Sugerida").font(.caption).foregroundStyle(.gray); Text(analysis.suggestedAction).bold().foregroundStyle(.orange) }
            }
            .padding().background(Color.white.opacity(0.05)).cornerRadius(10)
            
            if !analysis.coachComment.isEmpty {
                Text("\"\(analysis.coachComment)\"").font(.caption).italic().foregroundStyle(.gray)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            HStack {
                Button("Fechar") { dismiss() }.foregroundStyle(.gray)
                Spacer()
                Button("Aplicar Ajustes") { dismiss() }.foregroundStyle(Color.neonGreen).bold()
            }
        }.padding().glass()
    }
    
    // MARK: - Logic
    var rpeColor: Color { rpeSlider < 4 ? .blue : (rpeSlider < 8 ? .green : .red) }
    
    func durationString(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter(); formatter.allowedUnits = [.hour, .minute]; formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    func processWorkout() {
        // Dados reais para a IA
        let dist = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!)?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
        let dur = workout.duration / 60
        let kcal = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        let bpm = "N/A" // Se quiser extrair BPM médio, precisaria de mais queries no HKManager
        
        let dataStr = "Distância: \(String(format: "%.2f", dist))km, Duração: \(Int(dur))min, Calorias: \(Int(kcal)), Tipo: \(workout.workoutActivityType.name)"
        let feedback = "RPE: \(Int(rpeSlider))/10"
        
        aiService.analyzePostWorkout(workoutData: dataStr, userFeedback: feedback, painStatus: painSelected)
    }
}

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Corrida"
        case .walking: return "Caminhada"
        case .functionalStrengthTraining: return "Funcional"
        default: return "Outro"
        }
    }
}
