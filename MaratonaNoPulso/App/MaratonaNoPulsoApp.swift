import SwiftUI
import SwiftData

@main
struct MaratonaNoPulsoApp: App {
    
    // O Container que gerencia o banco de dados no disco
    let modelContainer: ModelContainer
    
    // Estado: O usuário já completou o onboarding?
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    
    init() {
        do {
            // ✅ IMPORTANTE: Incluir UserProfile no schema do banco
            modelContainer = try ModelContainer(for: SavedPlan.self, SavedWorkout.self, UserProfile.self)
        } catch {
            fatalError("Erro crítico ao criar banco de dados: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // 🧠 LÓGICA DE FLUXO: Se não completou o onboarding, mostra tela de cadastro
            if isOnboardingCompleted {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        // Injeta o banco de dados em todas as views do app
        .modelContainer(modelContainer)
    }
}
