import SwiftUI

struct MainTabView: View {
    // Estado para controlar qual aba está ativa
    @State private var selectedTab = 0
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(Color.appBackground).withAlphaComponent(0.9)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Passamos o Binding para o Coach poder mudar a aba
            VoiceCoachView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "waveform.path.ecg")
                    Text("Coach")
                }
                .tag(0)
            
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Dashboard")
                }
                .tag(1)
            
            LibraryView()
                .tabItem {
                    Image(systemName: "books.vertical")
                    Text("Biblioteca")
                }
                .tag(2)
        }
        .accentColor(Color.neonGreen)
        .preferredColorScheme(.dark)
    }
}
