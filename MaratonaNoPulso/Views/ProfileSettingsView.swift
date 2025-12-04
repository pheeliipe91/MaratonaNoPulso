import SwiftUI
import SwiftData

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Recebemos o perfil para edição
    @Bindable var profile: UserProfile
    
    // Opções para Picker
    let experienceLevels = ["Iniciante", "Intermediário", "Avançado", "Elite"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                Form {
                    Section("Identidade") {
                        TextField("Nome", text: $profile.name)
                        HStack {
                            Text("Idade")
                            Spacer()
                            TextField("Anos", value: $profile.age, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Peso (kg)")
                            Spacer()
                            TextField("Kg", value: $profile.weight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Section("Perfil Atlético") {
                        Picker("Nível", selection: $profile.experienceLevel) {
                            ForEach(experienceLevels, id: \.self) { level in
                                Text(level).tag(level)
                            }
                        }
                        
                        HStack {
                            Text("Frequência Semanal")
                            Spacer()
                            Stepper("\(profile.weeklyFrequency)x", value: $profile.weeklyFrequency, in: 1...7)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Section("Objetivo Principal") {
                        TextField("Ex: Maratona Sub 4h", text: $profile.mainGoal, axis: .vertical)
                            .lineLimit(3)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Section {
                        Button("Salvar Alterações") {
                            dismiss()
                        }
                        .foregroundStyle(Color.neonGreen)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
            }
            .navigationTitle("Editar Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Fechar") { dismiss() }
            }
        }
    }
}
