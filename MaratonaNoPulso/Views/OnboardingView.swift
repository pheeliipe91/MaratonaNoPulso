import SwiftUI
import SwiftData
import HealthKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    @Query private var existingProfiles: [UserProfile]
    
    // Estado
    @State private var currentPage = 0
    @State private var showProfileForm = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            if showProfileForm {
                ProfileFormView(onFinish: completeOnboarding)
                    .transition(.move(edge: .bottom))
            } else {
                VStack(spacing: 0) {
                    // Carrossel
                    TabView(selection: $currentPage) {
                        OnboardingCard(
                            title: "SHAPING\nYOUR RUN.",
                            subtitle: "A inteligência artificial criando treinos perfeitos para sua biometria.",
                            icon: "waveform.path.ecg",
                            accent: .neonGreen
                        ).tag(0)
                        
                        OnboardingCard(
                            title: "FROM PDF\nTO WATCH.",
                            subtitle: "Importe planilhas do seu treinador direto para o pulso em segundos.",
                            icon: "doc.viewfinder",
                            accent: .electricBlue
                        ).tag(1)
                        
                        OnboardingCard(
                            title: "HEALTH\nSYNCED.",
                            subtitle: "Conectado ao Apple Health para respeitar seu descanso e limites.",
                            icon: "heart.fill",
                            accent: .pink
                        ).tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Controles Inferiores
                    HStack {
                        // Indicadores de Página Customizados
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(currentPage == index ? Color.white : Color.white.opacity(0.2))
                                    .frame(width: 8, height: 8)
                                    .animation(.spring(), value: currentPage)
                            }
                        }
                        
                        Spacer()
                        
                        // Botão de Ação "Next" estilo seta
                        Button(action: nextPage) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    .frame(width: 60, height: 60)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(currentPage + 1) / 3.0)
                                    .stroke(Color.neonGreen, lineWidth: 2)
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-90))
                                
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            // Verifica se tem usuário antigo
            if !existingProfiles.isEmpty {
                // Opcional: Mostrar botão de "Restaurar"
            }
        }
    }
    
    func nextPage() {
        withAnimation {
            if currentPage < 2 {
                currentPage += 1
            } else {
                showProfileForm = true
            }
        }
    }
    
    func completeOnboarding() {
        withAnimation { isOnboardingCompleted = true }
    }
}

// MARK: - Componentes Visuais do Onboarding
struct OnboardingCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            
            // Ícone "Glowing"
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundStyle(accent)
            }
            .padding(.bottom, 20)
            
            Text(title)
                .font(.system(size: 60, weight: .black, design: .default)) // Fonte Impactante
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .lineSpacing(-10) // Aperta as linhas para efeito pôster
            
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.gray)
                .frame(maxWidth: 300, alignment: .leading)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileFormView: View {
    var onFinish: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var existingProfiles: [UserProfile]
    
    @State private var name = ""
    @State private var mainGoal = ""
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text("SYSTEM\nSETUP.")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                ModernTextField(title: "CODENAME", placeholder: "Seu Nome", text: $name)
                ModernTextField(title: "TARGET", placeholder: "Ex: Maratona 42k", text: $mainGoal)
            }
            
            // Botão Fake de HealthKit para demo visual
            HStack {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
                Text("Health Data Source")
                Spacer()
                Text("CONNECTED").font(.caption).bold().foregroundStyle(.green)
            }
            .padding()
            .glass()
            
            Spacer()
            
            Button(action: save) {
                Text("INITIATE PROTOCOL")
                    .font(.headline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(name.isEmpty ? Color.gray : Color.neonGreen)
                    .cornerRadius(12)
            }
            .disabled(name.isEmpty)
            .padding(.bottom, 40)
        }
        .padding(30)
        .background(Color.appBackground)
    }
    
    func save() {
        if let old = existingProfiles.first { modelContext.delete(old) }
        let profile = UserProfile(name: name, age: 30, weight: 70, experienceLevel: "Intermediário", mainGoal: mainGoal, weeklyFrequency: 3)
        modelContext.insert(profile)
        onFinish()
    }
}

struct ModernTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .tracking(2) // Espaçamento entre letras
                .foregroundStyle(.gray)
            
            TextField(placeholder, text: $text)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .foregroundStyle(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(text.isEmpty ? Color.white.opacity(0.1) : Color.neonGreen.opacity(0.5), lineWidth: 1)
                )
        }
    }
}
