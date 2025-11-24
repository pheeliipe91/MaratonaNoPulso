import SwiftUI

struct MainTabView: View {
    var body: some View {
        // O TabView gerencia as diferentes abas do seu app
        TabView {
            // Aba 1: AI Coach
            VoiceCoachView()
                .tabItem {
                    // Ícone e texto para a aba
                    Image(systemName: "waveform.path.ecg")
                    Text("AI Coach")
                }

            // Aba 2: Dashboard (uma tela temporária por enquanto)
            Text("Tela do Dashboard")
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Dashboard")
                }

            // Aba 3: Mentores (uma tela temporária por enquanto)
            Text("Tela dos Mentores")
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Mentores")
                }
        }
        // Para garantir que os ícones fiquem com a cor correta no modo escuro
        .accentColor(.white)
    }
}

#Preview {
    MainTabView()
}
