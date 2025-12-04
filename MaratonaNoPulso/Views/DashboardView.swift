import SwiftUI
import HealthKit
import Charts
import SwiftData

struct DashboardView: View {
    @StateObject private var hkManager = HealthKitManager.shared
    @Query private var userProfiles: [UserProfile]
    
    @State private var showProfileSheet = false
    @State private var animateChart = false
    
    // ✅ NOVO: Controle da tela de Inteligência Pós-Treino
    @State private var showPostWorkout = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fundo original
                LinearGradient(colors: [Color(hex: "0F0F10"), Color.appBackground], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                Circle().fill(Color.neonGreen.opacity(0.05)).frame(width: 400, height: 400).blur(radius: 120).offset(x: 150, y: -300)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // 1. Header (Original)
                        HStack {
                            VStack(alignment: .leading) {
                                Text("DASHBOARD").font(.caption).bold().tracking(2).foregroundStyle(Color.gray)
                                Text("Hoje, \(Date().formatted(.dateTime.day().month()))").font(.title2).bold().foregroundStyle(.white)
                            }
                            Spacer()
                            Button(action: { showProfileSheet = true }) {
                                Image(systemName: "person.circle.fill").font(.largeTitle).foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // ✅ 2. CARD DE INTELIGÊNCIA (Novo)
                        // Verifica se existe um treino HOJE no HealthKit
                        if let lastWorkout = hkManager.latestWorkout, Calendar.current.isDateInToday(lastWorkout.startDate) {
                            Button(action: { showPostWorkout = true }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TREINO DETECTADO")
                                            .font(.caption).bold().foregroundStyle(.black.opacity(0.6))
                                        Text("Analisar Performance")
                                            .font(.headline).bold().foregroundStyle(.black)
                                    }
                                    Spacer()
                                    Image(systemName: "brain.head.profile") // Ícone de IA
                                        .font(.title)
                                        .foregroundStyle(.black)
                                }
                                .padding()
                                .background(Color.neonGreen) // Destaque visual
                                .cornerRadius(16)
                                .shadow(color: Color.neonGreen.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal)
                        }
                        
                        // 3. Métricas Grid (Original)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            // Card Volume
                            VStack(alignment: .leading) {
                                Label("VOLUME (7d)", systemImage: "figure.run").font(.caption).bold().foregroundStyle(.neonGreen)
                                Spacer()
                                HStack(alignment: .firstTextBaseline) {
                                    Text(String(format: "%.1f", hkManager.weeklyDistance)).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    Text("km").font(.caption).foregroundStyle(.gray)
                                }
                            }
                            .padding()
                            .frame(height: 100)
                            .glass()
                            
                            // Card Calorias
                            VStack(alignment: .leading) {
                                Label("CALORIAS", systemImage: "flame.fill").font(.caption).bold().foregroundStyle(.orange)
                                Spacer()
                                HStack(alignment: .firstTextBaseline) {
                                    Text("\(Int(hkManager.todayCalories))").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    Text("kcal").font(.caption).foregroundStyle(.gray)
                                }
                            }
                            .padding()
                            .frame(height: 100)
                            .glass()
                        }
                        .padding(.horizontal)
                        
                        // 4. Gráfico Neon (Original)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("ATIVIDADE RECENTE").font(.caption).bold().tracking(2).foregroundStyle(.white)
                            
                            if hkManager.dailyHistory.isEmpty {
                                Text("Sem dados recentes.").font(.caption).foregroundStyle(.gray).frame(height: 180).frame(maxWidth: .infinity)
                            } else {
                                Chart(hkManager.dailyHistory) { item in
                                    BarMark(x: .value("Dia", item.day), y: .value("Km", animateChart ? item.distance : 0))
                                        .foregroundStyle(LinearGradient(colors: [.neonGreen, .neonGreen.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                        .cornerRadius(4)
                                }
                                .frame(height: 180)
                                .chartYAxis(.hidden)
                                .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Color.gray).font(.caption2) } }
                            }
                        }
                        .padding(20).glass().padding(.horizontal)
                        
                        // 5. Card Passos (Original)
                        HStack {
                            VStack(alignment: .leading) {
                                Text("PASSOS HOJE").font(.caption).bold().foregroundStyle(.gray)
                                Text("\(hkManager.todaySteps)").font(.title2).bold().foregroundStyle(.white)
                            }
                            Spacer()
                            CircularProgressView(progress: min(Double(hkManager.todaySteps)/10000, 1.0))
                                .frame(width: 40, height: 40)
                        }
                        .padding().glass().padding(.horizontal)
                        
                        HStack {
                            Image(systemName: "heart.text.square.fill").foregroundStyle(.pink)
                            Text("Sincronizado com Apple Health").font(.caption).foregroundStyle(.gray)
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .onAppear {
                hkManager.fetchAllData()
                hkManager.fetchLatestWorkout() // ✅ Busca treino recente ao abrir a tela
                withAnimation(.easeOut(duration: 1.0)) { animateChart = true }
            }
            .sheet(isPresented: $showProfileSheet) {
                if let user = userProfiles.first { ProfileSettingsView(profile: user) } else { Text("Erro: Perfil não encontrado.") }
            }
            // ✅ Sheet do Pós-Treino (Centro de Inteligência)
            .sheet(isPresented: $showPostWorkout) {
                if let workout = hkManager.latestWorkout {
                    PostWorkoutView(workout: workout)
                }
            }
        }
    }
}

// Micro Componente de Progresso (Original)
struct CircularProgressView: View {
    var progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 4)
            Circle().trim(from: 0, to: progress).stroke(Color.neonGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90)).animation(.easeOut, value: progress)
        }
    }
}
