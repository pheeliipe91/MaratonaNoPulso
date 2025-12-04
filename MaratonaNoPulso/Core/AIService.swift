import Foundation
import Combine

// MARK: - Estruturas Internas da "Science Engine"
struct WeekBlueprint: Codable {
    let focus: String
    let sessions: [SessionBlueprint]
}

struct SessionBlueprint: Codable {
    let day: String
    let type: String
    let targetDistanceKm: Double
    let targetDurationMin: Int
    let intensityConstraints: String
}

// 🆕 Contexto Atlético Unificado (SINGLE SOURCE OF TRUTH)
struct AthleteContext: Codable {
    let weeklyKm: Double
    let averagePace: String      // Ex: "6:30" (min/km)
    let longestRunKm: Double
    let recentWorkouts: Int
    let experienceLevel: String
    let hasHistory: Bool
    
    var paceInSeconds: Double {
        let parts = averagePace.split(separator: ":")
        guard parts.count == 2,
              let min = Double(parts[0]),
              let sec = Double(parts[1]) else { return 390 } // Fallback 6:30
        return (min * 60) + sec
    }
    
    // 🧠 Calcula pace target para diferentes zonas
    func targetPace(forZone zone: String) -> (min: String, max: String) {
        let baseSeconds = paceInSeconds
        
        switch zone.lowercased() {
        case "z1", "recovery", "recuperação":
            // +30s/km mais lento
            let slowMin = baseSeconds + 30
            let slowMax = baseSeconds + 60
            return (formatPace(slowMin), formatPace(slowMax))
            
        case "z2", "easy", "leve", "aeróbico":
            // Pace atual ± 15s
            let easyMin = baseSeconds + 10
            let easyMax = baseSeconds + 30
            return (formatPace(easyMin), formatPace(easyMax))
            
        case "z3", "tempo", "moderado":
            // -15s a -5s
            let tempoMin = baseSeconds - 20
            let tempoMax = baseSeconds - 5
            return (formatPace(tempoMin), formatPace(tempoMax))
            
        case "z4", "threshold", "limiar":
            // -30s a -20s
            let threshMin = baseSeconds - 35
            let threshMax = baseSeconds - 20
            return (formatPace(threshMin), formatPace(threshMax))
            
        case "z5", "vo2max", "intervalado", "tiro":
            // -45s ou mais rápido
            let vo2Min = baseSeconds - 50
            let vo2Max = baseSeconds - 35
            return (formatPace(vo2Min), formatPace(vo2Max))
            
        default:
            // Z2 como padrão
            return (formatPace(baseSeconds + 10), formatPace(baseSeconds + 30))
        }
    }
    
    private func formatPace(_ seconds: Double) -> String {
        let totalSec = max(180, min(600, seconds)) // Limita entre 3:00 e 10:00
        let min = Int(totalSec / 60)
        let sec = Int(totalSec.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", min, sec)
    }
}

// =================================================================
// MARK: - ARQUITETURA ENTERPRISE: LAYERS
// 1. Transport Layer (Rede)
// 2. DTO Layer (Dados Brutos/Opcionais)
// 3. Domain Mapper Layer (Regras de Negócio/Preenchimento de Falhas)
// =================================================================

class AIService: ObservableObject {
    // MARK: - Singleton
    static let shared = AIService()
    
    // MARK: - Outputs (Domain Layer - Só dados limpos chegam aqui)
    @Published var suggestedWorkouts: [AIWorkoutPlan] = []
    @Published var suggestedRoadmap: [CyclePhase] = []
    @Published var generatedSegments: [WorkoutSegment]?
    @Published var postWorkoutAnalysis: PostWorkoutAnalysis?
    
    // MARK: - State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var retryCount: Int = 0
    private let maxRetries = 2
    
    private let client = OpenAIClient() // Cérebro de Rede separado
    
    // Armazena assinaturas locais para evitar duplicação
    private var localExistingSignatures: Set<WorkoutSignature> = []
    
    // 🆕 CONTEXTO UNIFICADO: Armazena contexto de Health para garantir coerência
    private(set) var athleteContext: AthleteContext?  // 🔥 Mudado para private(set) para permitir leitura
    
    private init() {}  // 🔥 Privado para forçar uso do singleton
    
    // MARK: - 1. GERAÇÃO MACRO (SEMANA)
    func generateWeekPlan(for user: AIUserProfile, healthContext: String, instruction: String? = nil, existingPlans: [DailyPlan] = []) {
        startLoading()
        self.localExistingSignatures = Set(existingPlans.map { $0.signature })
        
        // 🔥 CALCULAR CONTEXTO ATLÉTICO (SINGLE SOURCE OF TRUTH)
        self.athleteContext = calculateAthleteContext(healthContext: healthContext, user: user)
        
        guard let context = self.athleteContext else {
            DispatchQueue.main.async {
                self.errorMessage = "Não foi possível processar seu histórico de treinos."
                self.isLoading = false
            }
            return
        }
        
        // 🚨 ALERTA: Usuário sem histórico
        if !context.hasHistory {
            print("⚠️ USUÁRIO SEM HISTÓRICO - Gerando plano adaptativo")
        }
        
        // Definição do Prompt (Com contexto enriquecido)
        let blueprint = calculateWeekBlueprint(for: user, context: context)
        let promptData = WeekPromptStrategy.build(
            user: user, 
            context: healthContext, 
            athleteContext: context,  // 🆕 Passa contexto calculado
            instruction: instruction, 
            blueprint: blueprint
        )
        
        client.fetch(system: promptData.system, prompt: promptData.user) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                // CAMADA DE ENGENHARIA: Decodifica seguro -> Enriquece -> Publica
                let safeResponse = WeekMapper.map(
                    json: data, 
                    existingSignatures: self.localExistingSignatures,
                    athleteContext: context  // 🆕 Passa contexto para validação
                )
                DispatchQueue.main.async {
                    self.suggestedRoadmap = safeResponse.roadmap
                    self.suggestedWorkouts = safeResponse.workouts
                    self.isLoading = false
                    
                    if safeResponse.workouts.isEmpty {
                        self.errorMessage = "A IA não retornou treinos válidos. Tente reformular."
                    }
                }
            case .failure(let error):
                self.handleError(error)
            }
        }
    }
    
    // MARK: - 2. GERAÇÃO MICRO (SEGMENTOS TÉCNICOS)
    func generateDetailedSegments(for instruction: String, title: String, phase: String, user: AIUserProfile) {
        startLoading()
        
        // 🔥 REUTILIZA O CONTEXTO DO PLANO ORIGINAL
        if self.athleteContext == nil {
            print("⚠️ Contexto atlético não disponível, usando fallback")
            // Se não tiver contexto, cria um básico
            self.athleteContext = AthleteContext(
                weeklyKm: user.currentDistance,
                averagePace: "6:30",  // Fallback conservador
                longestRunKm: max(5, user.currentDistance * 0.3),
                recentWorkouts: 0,
                experienceLevel: user.experienceLevel,
                hasHistory: false
            )
        }
        
        let promptData = SegmentPromptStrategy.build(
            title: title, 
            phase: phase, 
            instruction: instruction, 
            userLevel: user.experienceLevel,
            athleteContext: self.athleteContext  // 🆕 Passa contexto
        )
        
        client.fetch(system: promptData.system, prompt: promptData.user) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                // CAMADA DE ENGENHARIA: Sanitiza os segmentos e calcula paces faltantes
                let segments = SegmentMapper.map(
                    json: data, 
                    userLevel: user.experienceLevel,
                    athleteContext: self.athleteContext  // 🆕 Passa contexto
                )
                DispatchQueue.main.async {
                    self.generatedSegments = segments
                    self.isLoading = false
                }
            case .failure(let error):
                self.handleError(error)
            }
        }
    }
    
    // MARK: - 3. PÓS-TREINO
    func analyzePostWorkout(workoutData: String, userFeedback: String, painStatus: String) {
        startLoading()
        
        let prompt = "DADOS: \(workoutData). FEEDBACK: \(userFeedback), Dor: \(painStatus). Retorne JSON PostWorkoutAnalysis."
        
        client.fetch(system: "Fisiologista Esportivo.", prompt: prompt) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                if let analysis = try? JSONDecoder().decode(PostWorkoutAnalysis.self, from: data) {
                    DispatchQueue.main.async { self.postWorkoutAnalysis = analysis; self.isLoading = false }
                } else {
                    self.handleError(.decodingError)
                }
            case .failure(let error):
                self.handleError(error)
            }
        }
    }
    
    // MARK: - Helpers Privados
    private func startLoading() {
        DispatchQueue.main.async { 
            self.isLoading = true
            self.errorMessage = nil
            self.suggestedWorkouts = []
            self.generatedSegments = nil
            self.retryCount = 0 // ✅ Reset contador
        }
    }
    
    private func handleError(_ error: AIError) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            self.retryCount = 0
            print("❌ AIService: \(error.localizedDescription)")
        }
    }
    
    // 🆕 CALCULADORA DE CONTEXTO ATLÉTICO COM DADOS REAIS
    private func calculateAthleteContext(healthContext: String, user: AIUserProfile) -> AthleteContext {
        // Parse do healthContext string para extrair métricas básicas
        var weeklyKm = user.currentDistance
        var recentWorkouts = 0
        var longestRun = 0.0
        var totalDistance = 0.0
        
        // Regex para extrair dados do formato "- SEG: 5.2 km"
        let lines = healthContext.components(separatedBy: "\n")
        for line in lines {
            // Extrai distância (ex: "5.2 km")
            if let range = line.range(of: #"(\d+\.?\d*)\s*km"#, options: .regularExpression) {
                let distStr = String(line[range]).replacingOccurrences(of: "km", with: "").trimmingCharacters(in: .whitespaces)
                if let dist = Double(distStr), dist > 0 {
                    recentWorkouts += 1
                    totalDistance += dist
                    longestRun = max(longestRun, dist)
                }
            }
        }
        
        // Se encontrou dados, atualiza weeklyKm
        if totalDistance > 0 {
            weeklyKm = totalDistance
        }
        
        let hasHistory = recentWorkouts > 0
        
        // 🔥 CÁLCULO CIENTÍFICO DO PACE BASEADO EM DADOS REAIS
        let averagePace: String = calculateScientificPace(
            weeklyKm: weeklyKm,
            vo2Max: extractVO2MaxFromContext(healthContext),
            restingHR: extractRestingHRFromContext(healthContext),
            recentPace: extractRecentPaceFromContext(healthContext),
            hasHistory: hasHistory
        )
        
        print("📊 CONTEXTO ATLÉTICO CALCULADO (CIENTÍFICO):")
        print("   - Volume semanal: \(String(format: "%.1f", weeklyKm))km")
        print("   - Pace médio: \(averagePace)/km")
        print("   - Long run: \(String(format: "%.1f", longestRun))km")
        print("   - Treinos recentes: \(recentWorkouts)")
        print("   - Tem histórico: \(hasHistory)")
        
        return AthleteContext(
            weeklyKm: weeklyKm,
            averagePace: averagePace,
            longestRunKm: max(3, longestRun),
            recentWorkouts: recentWorkouts,
            experienceLevel: user.experienceLevel,
            hasHistory: hasHistory
        )
    }
    
    // 🔥 CÁLCULO CIENTÍFICO DE PACE
    private func calculateScientificPace(
        weeklyKm: Double,
        vo2Max: Double?,
        restingHR: Double?,
        recentPace: String?,
        hasHistory: Bool
    ) -> String {
        
        // 1️⃣ PRIORIDADE MÁXIMA: Pace real dos últimos treinos
        if let recentPace = recentPace {
            print("   🎯 Usando pace REAL dos treinos recentes: \(recentPace)")
            return recentPace
        }
        
        // 2️⃣ Se tem VO2Max, calcula baseado nisso
        if let vo2 = vo2Max {
            let pace = calculatePaceFromVO2Max(vo2)
            print("   🎯 Calculado a partir de VO2Max (\(String(format: "%.1f", vo2))): \(pace)")
            return pace
        }
        
        // 3️⃣ Se tem FC repouso, estima condicionamento
        if let rhr = restingHR {
            let pace = calculatePaceFromRestingHR(rhr, weeklyKm: weeklyKm)
            print("   🎯 Calculado a partir de FC repouso (\(String(format: "%.0f", rhr))bpm): \(pace)")
            return pace
        }
        
        // 4️⃣ Fallback: Volume semanal (método antigo, menos preciso)
        if hasHistory && weeklyKm > 0 {
            let pace = calculatePaceFromVolume(weeklyKm)
            print("   ⚠️ Calculado APENAS por volume (menos preciso): \(pace)")
            return pace
        }
        
        // 5️⃣ Sem histórico: pace conservador
        print("   ⚠️ SEM HISTÓRICO: Usando pace conservador")
        return "7:30"
    }
    
    // 🧬 Calcula pace a partir do VO2Max (método científico mais preciso)
    private func calculatePaceFromVO2Max(_ vo2: Double) -> String {
        // Fórmula de Jack Daniels: VDOT (VO2Max) correlaciona com pace
        // VO2Max de 42 = corredor intermediário-avançado
        // Pace de treino fácil (Z2) = aproximadamente 70-75% do VO2Max
        
        let vdot = vo2
        
        // Estimativa de pace por VDOT (tabela simplificada)
        let paceSeconds: Double
        switch vdot {
        case 60...: paceSeconds = 240  // 4:00/km - Elite
        case 55..<60: paceSeconds = 270  // 4:30/km - Avançado
        case 50..<55: paceSeconds = 300  // 5:00/km - Intermediário-Avançado
        case 45..<50: paceSeconds = 330  // 5:30/km - Intermediário
        case 40..<45: paceSeconds = 360  // 6:00/km - Intermediário-Iniciante
        case 35..<40: paceSeconds = 390  // 6:30/km - Iniciante
        default: paceSeconds = 420  // 7:00/km - Muito iniciante
        }
        
        let minutes = Int(paceSeconds / 60)
        let seconds = Int(paceSeconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 💓 Calcula pace a partir da FC repouso
    private func calculatePaceFromRestingHR(_ rhr: Double, weeklyKm: Double) -> String {
        // FC repouso é indicador de condicionamento cardiovascular
        // Quanto menor, melhor o condicionamento
        
        let paceSeconds: Double
        switch rhr {
        case ..<50: paceSeconds = 300  // 5:00/km - Muito bom
        case 50..<55: paceSeconds = 330  // 5:30/km - Bom
        case 55..<60: paceSeconds = 360  // 6:00/km - Regular
        case 60..<65: paceSeconds = 390  // 6:30/km - Iniciante
        default: paceSeconds = 420  // 7:00/km - Precisa melhorar base
        }
        
        // Ajusta pelo volume (mais volume = melhor pace)
        let volumeAdjustment: Double
        switch weeklyKm {
        case 40...: volumeAdjustment = -30  // -30s para alto volume
        case 30..<40: volumeAdjustment = -15  // -15s para médio-alto
        case 20..<30: volumeAdjustment = 0    // Sem ajuste
        default: volumeAdjustment = 15  // +15s para baixo volume
        }
        
        let adjustedPace = paceSeconds + volumeAdjustment
        let minutes = Int(adjustedPace / 60)
        let seconds = Int(adjustedPace.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 📊 Calcula pace apenas pelo volume (menos preciso)
    private func calculatePaceFromVolume(_ weeklyKm: Double) -> String {
        let paceSeconds: Double
        switch weeklyKm {
        case 0..<10: paceSeconds = 420  // 7:00/km
        case 10..<20: paceSeconds = 390  // 6:30/km
        case 20..<35: paceSeconds = 360  // 6:00/km
        case 35..<50: paceSeconds = 330  // 5:30/km
        default: paceSeconds = 300  // 5:00/km
        }
        
        let minutes = Int(paceSeconds / 60)
        let seconds = Int(paceSeconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 🔍 Extratores de dados do healthContext
    private func extractVO2MaxFromContext(_ context: String) -> Double? {
        if let range = context.range(of: #"VO2Max:\s*(\d+\.?\d*)"#, options: .regularExpression) {
            let match = String(context[range])
            if let vo2 = Double(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                return vo2
            }
        }
        return nil
    }
    
    private func extractRestingHRFromContext(_ context: String) -> Double? {
        if let range = context.range(of: #"FC Repouso:\s*(\d+)"#, options: .regularExpression) {
            let match = String(context[range])
            if let hr = Double(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                return hr
            }
        }
        return nil
    }
    
    private func extractRecentPaceFromContext(_ context: String) -> String? {
        if let range = context.range(of: #"Pace Médio:\s*(\d+:\d+)"#, options: .regularExpression) {
            let match = String(context[range])
            let pacePattern = #"\d+:\d+"#
            if let paceRange = match.range(of: pacePattern, options: .regularExpression) {
                return String(match[paceRange])
            }
        }
        return nil
    }
    
    // Lógica simples de Blueprint (Necessária para o prompt strategy)
    private func calculateWeekBlueprint(for user: AIUserProfile, context: AthleteContext) -> WeekBlueprint {
        let baseVolume = context.weeklyKm > 0 ? context.weeklyKm : 15.0
        let safeVolume = min(baseVolume * 1.10, baseVolume + 4.0)  // Máximo 10% ou 4km de aumento
        let longRun = (safeVolume * 0.30).rounded()
        let easyRun = ((safeVolume - longRun) / Double(max(1, user.daysPerWeek - 1))).rounded()
        
        var sessions: [SessionBlueprint] = []
        sessions.append(SessionBlueprint(
            day: "Sábado", 
            type: "Long Run", 
            targetDistanceKm: longRun, 
            targetDurationMin: Int(longRun * 7), 
            intensityConstraints: "Z2 @ \(context.averagePace)"
        ))
        
        if user.daysPerWeek > 1 {
            for _ in 0..<(user.daysPerWeek - 1) {
                sessions.append(SessionBlueprint(
                    day: "Semana", 
                    type: "Easy Run", 
                    targetDistanceKm: easyRun, 
                    targetDurationMin: Int(easyRun * 7), 
                    intensityConstraints: "Z1/Z2 @ \(context.averagePace) ou mais lento"
                ))
            }
        }
        return WeekBlueprint(focus: "Base", sessions: sessions)
    }
}

// =================================================================
// MARK: - MÓDULO 1: CLIENTE DE REDE (Network Layer)
// Responsabilidade: Apenas falar com a OpenAI e entregar Data limpo.
// =================================================================

enum AIError: Error {
    case invalidURL
    case connectionError(String)
    case noData
    case decodingError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Erro interno de configuração de URL."
        case .connectionError(let msg): return "Falha na conexão: \(msg)"
        case .noData: return "A IA retornou uma resposta vazia."
        case .decodingError: return "Não foi possível ler os dados retornados."
        }
    }
}

class OpenAIClient {
    private let apiKey = Secrets.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    // ✅ Rate Limiting simplificado (sem lock)
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 1.0 // Reduzido para 1 segundo
    
    func fetch(system: String, prompt: String, completion: @escaping (Result<Data, AIError>) -> Void) {
        // ✅ Verifica rate limit (não-bloqueante)
        if let lastTime = lastRequestTime,
           Date().timeIntervalSince(lastTime) < minimumRequestInterval {
            print("⚠️ Rate limit: Aguardando intervalo mínimo...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.fetch(system: system, prompt: prompt, completion: completion)
            }
            return
        }
        
        lastRequestTime = Date()
        // 0. Diagnóstico Prévio (Teste de conectividade)
        checkConnectivity { [weak self] isConnected in
            guard let self = self else { return }
            
            if !isConnected {
                print("❌ Teste de conectividade falhou")
                completion(.failure(.connectionError("Sem conexão com a internet.")))
                return
            }
            
            print("✅ Conectividade OK, iniciando OpenAI...")
            self.executeOpenAICall(system: system, prompt: prompt, maxTokens: 4000, completion: completion)
        }
    }
    
    // MARK: - Helpers de Rede (Diagnóstico Avançado)
    
    private func checkConnectivity(completion: @escaping (Bool) -> Void) {
        print("🔍 Testando conectividade...")
        
        guard let url = URL(string: "https://www.google.com") else { 
            completion(false)
            return 
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3  // ✅ Reduzido de 5 para 3 segundos
        config.timeoutIntervalForResource = 3
        let session = URLSession(configuration: config)
        
        session.dataTask(with: url) { _, response, error in
            if let error = error {
                print("❌ Conectividade falhou: \(error.localizedDescription)")
                completion(false)
            } else if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                print("✅ Conectividade OK")
                completion(true)
            } else {
                print("⚠️ Status duvidoso, prosseguindo...")
                completion(true)
            }
        }.resume()
    }
    
    private func executeOpenAICall(system: String, prompt: String, maxTokens: Int, completion: @escaping (Result<Data, AIError>) -> Void) {
        let cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleanEndpoint) else { 
            completion(.failure(.invalidURL))
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30  // ✅ Reduzido de 60 para 30 segundos
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.5,
            "max_tokens": maxTokens,
            "response_format": ["type": "json_object"]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Falha ao serializar JSON Body: \(error.localizedDescription)")
            completion(.failure(.decodingError))
            return
        }
        
        print("🚀 Iniciando chamada OpenAI (endpoint: \(cleanEndpoint))...")
        
        // Configuração "Ephemeral" (Sem Cache/Cookies)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30  // ✅ Reduzido de 60 para 30
        config.timeoutIntervalForResource = 45  // ✅ Limite total
        let session = URLSession(configuration: config)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Tratamento de Erro Detalhado
            if let error = error as? URLError {
                let errorType: String
                switch error.code {
                case .notConnectedToInternet: 
                    errorType = "Sem Internet"
                case .timedOut: 
                    errorType = "Timeout (Servidor não respondeu a tempo)"
                case .cannotFindHost: 
                    errorType = "DNS Falhou (Não encontrou api.openai.com)"
                case .cannotConnectToHost: 
                    errorType = "Porta Fechada/Recusada"
                case .secureConnectionFailed: 
                    errorType = "Falha SSL (Verifique data/hora do sistema)"
                default: 
                    errorType = "Erro de Rede (\(error.code.rawValue))"
                }
                
                print("❌ ERRO DETALHADO: \(errorType) - \(error.localizedDescription)")
                completion(.failure(.connectionError(errorType)))
                return
            }
            
            // Análise de resposta HTTP
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 401:
                    print("❌ Erro 401: API Key inválida ou expirada")
                    completion(.failure(.connectionError("API Key inválida ou expirada")))
                    return
                case 429:
                    print("❌ Erro 429: Limite de cotas excedido")
                    completion(.failure(.connectionError("Limite de requisições excedido. Tente novamente mais tarde.")))
                    return
                case 200...299:
                    break // Sucesso, continua
                default:
                    if let data = data, let txt = String(data: data, encoding: .utf8) {
                        print("❌ Server Response: \(txt)")
                    }
                    completion(.failure(.connectionError("Erro do servidor: \(httpResponse.statusCode)")))
                    return
                }
            }
            
            guard let data = data else { 
                print("❌ Resposta vazia do servidor")
                completion(.failure(.noData))
                return 
            }
            
            print("📦 Dados recebidos: \(data.count) bytes")
            
            // Extração do conteúdo
            if let content = self.extractMessageContent(from: data) {
                print("✅ Sucesso! JSON extraído e validado")
                completion(.success(content))
            } else {
                print("❌ Falha ao extrair conteúdo da resposta")
                completion(.failure(.decodingError))
            }
            
        }.resume()
    }
    
    private func extractMessageContent(from data: Data) -> Data? {
        struct Response: Decodable { 
            struct Choice: Decodable { 
                struct Msg: Decodable { 
                    let content: String 
                }
                let message: Msg 
            }
            let choices: [Choice] 
        }
        
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let contentString = decoded.choices.first?.message.content else { 
            print("❌ Falha ao decodificar resposta da OpenAI")
            return nil 
        }
        
        let cleanString = contentString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanString.data(using: .utf8)
    }
}

// =================================================================
// MARK: - MÓDULO 2: DTOs BLINDADOS (Data Transfer Objects)
// Responsabilidade: Receber dados parciais/sujos sem quebrar.
// =================================================================

struct SafeSegmentDTO: Decodable {
    let role: String?
    let goalType: String?
    let distanceKm: Double?
    let durationMinutes: Double?
    let intensity: String?
    let targetPaceMin: String?
    let targetPaceMax: String?
    let reps: Int?
}

struct SafeWorkoutDTO: Decodable {
    let title: String?
    let description: String?
    let distance: Double?
    let duration: Int?
    let type: String?
    let suggestedDay: String?
    let cyclePhase: String?
    let rawInstructionText: String?
    
    // 🆕 Organização hierárquica
    let weekNumber: Int?
    
    // 🆕 Parâmetros de força
    let sets: Int?
    let reps: String?
    let restSeconds: Int?
    let exercises: [String]?
    let strengthNotes: String?
    
    // Campos adicionais
    let cycleTarget: String?
    let workoutReasoning: String?
    let safetyWarning: String?
    let zoneFocus: String?
    let difficultyRating: String?
}

// =================================================================
// MARK: - MÓDULO 3: ENGENHARIA & MAPPERS (Domain Logic)
// Responsabilidade: Transformar DTOs sujos em Models perfeitos.
// =================================================================

struct SegmentMapper {
    static func map(json: Data, userLevel: String, athleteContext: AthleteContext?) -> [WorkoutSegment] {
        // Tenta decodificar array ou objeto wrapper
        var dtos: [SafeSegmentDTO] = []
        
        struct Wrapper: Decodable { let segments: [SafeSegmentDTO]? }
        
        if let wrapper = try? JSONDecoder().decode(Wrapper.self, from: json) {
            dtos = wrapper.segments ?? []
        } else if let array = try? JSONDecoder().decode([SafeSegmentDTO].self, from: json) {
            dtos = array
        }
        
        print("🔧 SegmentMapper recebeu \(dtos.count) segmentos")
        
        // ENGENHARIA: Preencher dados faltantes e injetar Pace
        return dtos.compactMap { dto in
            let role = SegmentRole(rawValue: dto.role ?? "work") ?? .work
            let goalType = GoalType(rawValue: dto.goalType ?? "time") ?? .time
            
            // 🔥 INTELIGÊNCIA DE FALLBACK: Nunca deixa vazio
            var duration = dto.durationMinutes
            var distance = dto.distanceKm
            
            // Se for tempo mas não tem duração, estima
            if goalType == .time && (duration == nil || duration == 0) {
                duration = estimateDuration(for: role)
                print("   ⚠️ Duração faltando para \(role.rawValue), usando fallback: \(duration!)min")
            }
            
            // Se for distância mas não tem km, estima
            if goalType == .distance && (distance == nil || distance == 0) {
                distance = estimateDistance(for: role)
                print("   ⚠️ Distância faltando para \(role.rawValue), usando fallback: \(distance!)km")
            }
            
            // Se AMBOS estão zerados, pula este segmento (inválido)
            if (duration == nil || duration == 0) && (distance == nil || distance == 0) {
                print("   ❌ Segmento inválido (sem tempo nem distância), ignorando")
                return nil
            }
            
            // 1. Calculando Pace baseado no contexto atlético
            var paceMin = dto.targetPaceMin
            var paceMax = dto.targetPaceMax
            
            if role == .work && paceMin == nil {
                // 🔥 USA CONTEXTO ATLÉTICO PARA CALCULAR PACE CORRETO
                if let context = athleteContext {
                    let intensity = dto.intensity ?? "Moderado"
                    let targetPaces = context.targetPace(forZone: intensity)
                    paceMin = targetPaces.min
                    paceMax = targetPaces.max
                    print("   🎯 Pace calculado para \(intensity): \(paceMin!) - \(paceMax!)")
                } else {
                    // Fallback antigo
                    paceMin = estimatePace(intensity: dto.intensity, level: userLevel, type: "min")
                    paceMax = estimatePace(intensity: dto.intensity, level: userLevel, type: "max")
                }
            }
            
            let segment = WorkoutSegment(
                role: role,
                goalType: goalType,
                durationMinutes: duration,
                distanceKm: distance,
                intensity: dto.intensity ?? "Moderado",
                targetPaceMin: paceMin,
                targetPaceMax: paceMax,
                reps: dto.reps
            )
            
            print("   ✅ Segmento criado: \(role.rawValue) - \(segment.summary) @ \(paceMin ?? "N/A")")
            return segment
        }
    }
    
    // 🧠 Estima duração baseada no tipo de segmento
    private static func estimateDuration(for role: SegmentRole) -> Double {
        switch role {
        case .warmup: return 10.0
        case .work: return 20.0
        case .recovery: return 5.0
        case .cooldown: return 10.0
        }
    }
    
    // 🧠 Estima distância baseada no tipo de segmento
    private static func estimateDistance(for role: SegmentRole) -> Double {
        switch role {
        case .warmup: return 1.0
        case .work: return 5.0
        case .recovery: return 0.5
        case .cooldown: return 1.0
        }
    }
    
    // "Fallback Intelligence": Se a IA esqueceu o pace, nós calculamos.
    private static func estimatePace(intensity: String?, level: String, type: String) -> String {
        // Lógica simplificada: num app real, isso seria uma tabela completa
        let isAdvanced = level.lowercased().contains("avançado")
        if type == "min" { return isAdvanced ? "4:15" : "6:00" }
        return isAdvanced ? "4:45" : "6:30"
    }
}

struct WeekMapper {
    static func map(json: Data, existingSignatures: Set<WorkoutSignature>, athleteContext: AthleteContext?) -> (roadmap: [CyclePhase], workouts: [AIWorkoutPlan]) {
        struct WeekWrapper: Decodable { let roadmap: [CyclePhase]?; let workouts: [SafeWorkoutDTO]? }
        
        // 🔍 DEBUG: Ver o JSON (primeiros 500 chars apenas)
        if let jsonString = String(data: json, encoding: .utf8) {
            let preview = String(jsonString.prefix(500))
            print("📄 JSON PREVIEW: \(preview)...")
        }
        
        guard let wrapper = try? JSONDecoder().decode(WeekWrapper.self, from: json) else { 
            print("❌ ERRO: Falha ao decodificar WeekWrapper")
            return ([], []) 
        }
        
        print("✅ Decodificado: \(wrapper.workouts?.count ?? 0) treinos")
        
        let validWorkouts = (wrapper.workouts ?? []).compactMap { dto -> AIWorkoutPlan? in
            guard let title = dto.title else { 
                print("   ⚠️ Treino sem título, ignorando")
                return nil 
            }
            
            // 🔥 ENGENHARIA DE FALLBACK: Nunca deixa dist/dur zerados
            var dist = dto.distance ?? 0.0
            var dur = dto.duration ?? 0
            
            let workoutType = (dto.type ?? "General").lowercased()
            
            // Lógica de inferência baseada no tipo
            if workoutType.contains("rest") || workoutType.contains("descanso") {
                // Descanso não precisa de distância/duração
                dist = 0
                dur = 0
            } else if workoutType.contains("strength") || workoutType.contains("força") {
                // Treino de força: usa duração padrão se não tiver
                if dur == 0 { dur = 45 }  // 45 min padrão para força
                dist = 0  // Não tem distância
            } else {
                // Corrida/Cardio: precisa de valores válidos
                if dist == 0 && dur == 0 {
                    // Se ambos zerados, usa valores padrão
                    dist = 5.0  // 5km padrão
                    dur = 30    // 30min padrão
                    print("   ⚠️ '\(title)': Dist/Dur zerados, usando fallback: \(dist)km / \(dur)min")
                } else if dist > 0 && dur == 0 {
                    // Tem distância, calcula duração (6min/km = pace médio)
                    dur = Int(dist * 6.0)
                    print("   ℹ️ '\(title)': Inferindo duração de \(dist)km -> \(dur)min")
                } else if dur > 0 && dist == 0 {
                    // Tem duração, calcula distância
                    dist = Double(dur) / 6.0
                    print("   ℹ️ '\(title)': Inferindo distância de \(dur)min -> \(String(format: "%.1f", dist))km")
                }
            }
            
            // 🆕 Montar StrengthParameters se for treino de força
            var strengthParams: StrengthParameters? = nil
            if workoutType.contains("strength") || workoutType.contains("força") {
                strengthParams = StrengthParameters(
                    sets: dto.sets,
                    reps: dto.reps,
                    restSeconds: dto.restSeconds,
                    exercises: dto.exercises,
                    notes: dto.strengthNotes
                )
            }
            
            let plan = AIWorkoutPlan(
                title: title,
                description: dto.description,
                distance: dist,
                duration: dur,
                type: dto.type ?? "General",
                suggestedDay: dto.suggestedDay ?? "Dia Livre",
                cyclePhase: dto.cyclePhase,
                cycleTarget: dto.cycleTarget,
                rawInstructionText: dto.rawInstructionText,
                workoutReasoning: dto.workoutReasoning,
                segments: nil,
                safetyWarning: dto.safetyWarning,
                zoneFocus: dto.zoneFocus,
                difficultyRating: dto.difficultyRating,
                weekNumber: dto.weekNumber,
                strengthParams: strengthParams
            )
            
            print("   ✅ '\(title)': \(dist)km, \(dur)min, Semana \(dto.weekNumber ?? 1)")
            
            return plan
        }
        
        let unique = validWorkouts.filter { !existingSignatures.contains($0.signature) }
        
        print("📊 RESULTADO: \(validWorkouts.count) validados, \(unique.count) únicos")
        
        return (wrapper.roadmap ?? [], unique)
    }
}

// =================================================================
// MARK: - MÓDULO 4: FACTORY DE PROMPTS
// =================================================================

struct SegmentPromptStrategy {
    static func build(title: String, phase: String, instruction: String, userLevel: String, athleteContext: AthleteContext?) -> (system: String, user: String) {
        
        let paceContext = athleteContext.map { context in
            """
            
            PACE ATUAL DO ATLETA: \(context.averagePace)/km
            - Z1 (Recuperação): \(context.targetPace(forZone: "z1").min) - \(context.targetPace(forZone: "z1").max)
            - Z2 (Aeróbico): \(context.targetPace(forZone: "z2").min) - \(context.targetPace(forZone: "z2").max)
            - Z3 (Tempo): \(context.targetPace(forZone: "z3").min) - \(context.targetPace(forZone: "z3").max)
            - Z4 (Limiar): \(context.targetPace(forZone: "z4").min) - \(context.targetPace(forZone: "z4").max)
            - Z5 (VO2Max): \(context.targetPace(forZone: "z5").min) - \(context.targetPace(forZone: "z5").max)
            
            IMPORTANTE: Use SEMPRE esses paces calculados. NÃO invente valores.
            """
        } ?? ""
        
        let schema = """
        { "segments": [ { "role": "work", "goalType": "distance", "distanceKm": 1.0, "intensity": "Z4", "targetPaceMin": "4:30", "targetPaceMax": "4:45" } ] }
        """
        
        let system = """
        Engine de Treinos Enterprise.
        REGRAS RÍGIDAS:
        1. Campos 'targetPaceMin'/'Max' são OBRIGATÓRIOS para role='work'.
        2. Não use null. Se não souber, estime para nível \(userLevel).
        \(paceContext)
        Schema: \(schema)
        """
        
        let user = "Treino: \(title). Instr: \(instruction). Gere JSON com paces baseados no contexto fornecido."
        return (system, user)
    }
}

struct WeekPromptStrategy {
    static func build(user: AIUserProfile, context: String, athleteContext: AthleteContext, instruction: String?, blueprint: WeekBlueprint) -> (system: String, user: String) {
        
        // 🔥 EXTRAI NÚMERO DE SEMANAS DO PEDIDO
        let requestedWeeks = extractWeeksFromRequest(instruction: instruction)
        
        // 🔥 Contexto de Pace dinâmico
        let paceGuidance = """
        
        📊 ANÁLISE DO ATLETA (OBRIGATÓRIO SEGUIR):
        - Volume semanal atual: \(String(format: "%.1f", athleteContext.weeklyKm))km
        - Pace médio: \(athleteContext.averagePace)/km
        - Long run máximo: \(String(format: "%.1f", athleteContext.longestRunKm))km
        - Treinos recentes: \(athleteContext.recentWorkouts)
        - Tem histórico: \(athleteContext.hasHistory ? "SIM" : "⚠️ NÃO - Usar plano adaptativo")
        
        🎯 PACES CALIBRADOS (USE SEMPRE ESTES VALORES):
        - Corrida Leve (Z2): \(athleteContext.targetPace(forZone: "z2").min) - \(athleteContext.targetPace(forZone: "z2").max)
        - Corrida Moderada (Z3): \(athleteContext.targetPace(forZone: "z3").min) - \(athleteContext.targetPace(forZone: "z3").max)
        - Long Run: \(athleteContext.targetPace(forZone: "z2").min) (sempre Z2)
        - Intervalado/Tiros (Z5): \(athleteContext.targetPace(forZone: "z5").min) - \(athleteContext.targetPace(forZone: "z5").max)
        
        ⚠️ REGRA FUNDAMENTAL: NÃO sugira paces mais rápidos que os calculados acima.
        """
        
        // 🚨 Alerta para usuários sem histórico
        let noHistoryWarning = !athleteContext.hasHistory ? """
        
        🚨 ATENÇÃO: USUÁRIO SEM HISTÓRICO DE CORRIDA
        - Você DEVE criar um plano adaptativo e progressivo
        - Comece com caminhada + corrida leve (3-5km)
        - Aumente GRADUALMENTE (máximo 10% por semana)
        - Inclua PELO MENOS 2-3 treinos de força por semana
        - Exemplo de progressão: Semana 1 (3km), Semana 2 (4km), Semana 3 (5km), etc.
        - Meta final deve ser realista (ex: Se quer maratona, plano de 6-8 MESES mínimo)
        """ : ""
        
        // 🔥 EXEMPLO EXPANDIDO COM MÚLTIPLAS SEMANAS
        let exampleSchema = """
        {
          "roadmap": [
            {"phaseName": "Base", "duration": "4 semanas", "focus": "Aeróbico"},
            {"phaseName": "Construção", "duration": "4 semanas", "focus": "Resistência"}
          ],
          "workouts": [
            // SEMANA 1
            {"title": "Caminhada + Corrida Leve", "distance": 3.0, "duration": 25, "type": "outdoor_run", "suggestedDay": "Segunda", "cyclePhase": "Base", "weekNumber": 1},
            {"title": "Treino de Força", "distance": 0, "duration": 45, "type": "strength", "suggestedDay": "Terça", "cyclePhase": "Base", "weekNumber": 1, "sets": 3, "reps": "12-15", "exercises": ["Agachamento", "Lunges"]},
            {"title": "Corrida Leve", "distance": 4.0, "duration": 30, "type": "outdoor_run", "suggestedDay": "Quinta", "cyclePhase": "Base", "weekNumber": 1},
            {"title": "Descanso Ativo", "distance": 0, "duration": 0, "type": "rest", "suggestedDay": "Domingo", "cyclePhase": "Base", "weekNumber": 1},
            
            // SEMANA 2 (SEMPRE INCLUA TODAS AS SEMANAS!)
            {"title": "Corrida Progressiva", "distance": 4.0, "duration": 30, "type": "outdoor_run", "suggestedDay": "Segunda", "cyclePhase": "Base", "weekNumber": 2},
            {"title": "Treino de Força", "distance": 0, "duration": 45, "type": "strength", "suggestedDay": "Terça", "cyclePhase": "Base", "weekNumber": 2, "sets": 3, "reps": "10-12", "exercises": ["Agachamento", "Step-up"]},
            {"title": "Long Run Inicial", "distance": 6.0, "duration": 45, "type": "outdoor_run", "suggestedDay": "Sábado", "cyclePhase": "Base", "weekNumber": 2},
            {"title": "Descanso", "distance": 0, "duration": 0, "type": "rest", "suggestedDay": "Domingo", "cyclePhase": "Base", "weekNumber": 2},
            
            // ... CONTINUE ATÉ A ÚLTIMA SEMANA SOLICITADA
          ]
        }
        """
        
        let system = """
        Você é um Coach de Corrida Expert BASEADO EM CIÊNCIA. 
        
        🔥 REGRA CRÍTICA DE GERAÇÃO:
        - O usuário pediu \(requestedWeeks) SEMANAS
        - Você DEVE gerar EXATAMENTE \(requestedWeeks) semanas completas
        - Cada semana deve ter 3-5 treinos (incluindo descanso)
        - TOTAL DE TREINOS: aproximadamente \(requestedWeeks * 4) treinos
        - Distribua os treinos de 1 até \(requestedWeeks) usando "weekNumber"
        
        REGRAS OBRIGATÓRIAS:
        1. SEMPRE retorne JSON válido com a estrutura EXATA mostrada abaixo
        2. Campo "workouts" é ARRAY e OBRIGATÓRIO (mesmo que vazio)
        3. Campo "roadmap" é ARRAY e OBRIGATÓRIO (mesmo que vazio)
        4. Campos NUMÉRICOS são obrigatórios:
           - "distance": número (km) - Use 0 para descanso ou força
           - "duration": número (minutos) - NUNCA envie null ou 0 para corridas
           - "weekNumber": número (1, 2, 3... até \(requestedWeeks)) - SEMPRE inclua
        5. Campo "title" é obrigatório em cada workout
        6. Para treinos de FORÇA, inclua: sets, reps, restSeconds, exercises
        7. Para DESCANSO: distance=0, duration=0, type="rest"
        8. Para CORRIDA: distance e duration SEMPRE > 0
        
        ⚠️ IMPORTANTE: NÃO pare na semana 1 ou 2! Gere TODAS as \(requestedWeeks) semanas!
        
        ESTRUTURA ESPERADA:
        - Semana 1: 4 treinos (weekNumber: 1)
        - Semana 2: 4 treinos (weekNumber: 2)
        - Semana 3: 4 treinos (weekNumber: 3)
        - ... até Semana \(requestedWeeks)
        
        VALORES PADRÃO:
        - Corrida Leve: 5km, 30min
        - Long Run: 10km, 60min
        - Treino de Força: 0km, 45min
        - Descanso: 0km, 0min
        
        \(paceGuidance)
        \(noHistoryWarning)
        
        SCHEMA ESPERADO (MÚLTIPLAS SEMANAS):
        \(exampleSchema)
        
        NÃO adicione texto antes ou depois do JSON. Apenas o JSON puro.
        """
        
        if let instr = instruction, !instr.isEmpty {
            let userPrompt = """
            PEDIDO DO USUÁRIO: \(instr)
            
            🎯 NÚMERO DE SEMANAS DETECTADO: \(requestedWeeks)
            
            CONTEXTO DE SAÚDE:
            \(context)
            
            INSTRUÇÕES CRÍTICAS: 
            1. Gere \(requestedWeeks) SEMANAS COMPLETAS (não apenas 1 ou 2!)
            2. Total aproximado: \(requestedWeeks * 4) treinos
            3. Cada treino deve ter "weekNumber" de 1 até \(requestedWeeks)
            4. Exemplo de distribuição:
               - Semana 1: treinos com weekNumber: 1
               - Semana 2: treinos com weekNumber: 2
               - ...
               - Semana \(requestedWeeks): treinos com weekNumber: \(requestedWeeks)
            5. Para cada treino de corrida, SEMPRE preencha distance e duration
            6. Para força, preencha sets, reps, exercises
            7. USE OS PACES CALCULADOS acima. NÃO invente valores mais rápidos.
            \(athleteContext.hasHistory ? "" : "\n⚠️ SEM HISTÓRICO: Crie plano adaptativo começando com caminhada/corrida leve")
            
            Gere o plano COMPLETO de \(requestedWeeks) semanas seguindo o schema JSON exato.
            """
            return (system, userPrompt)
        } else {
            return (system, "Siga o Blueprint: \(blueprint.safeJsonString). Contexto: \(context). Retorne JSON no formato especificado com weekNumber em cada treino e paces calibrados.")
        }
    }
    
    // 🔥 EXTRATOR DE SEMANAS DO PEDIDO
    private static func extractWeeksFromRequest(instruction: String?) -> Int {
        guard let instr = instruction?.lowercased() else { return 4 }
        
        // Padrões comuns
        if instr.contains("2 meses") || instr.contains("dois meses") {
            return 8  // 2 meses = 8 semanas
        }
        if instr.contains("3 meses") || instr.contains("três meses") {
            return 12
        }
        if instr.contains("1 mês") || instr.contains("um mês") {
            return 4
        }
        
        // Procura "X semanas"
        let patterns = [
            #"(\d+)\s*semanas?"#,
            #"(uma|dois|duas|três|quatro|cinco|seis|sete|oito)\s*semanas?"#
        ]
        
        for pattern in patterns {
            if let range = instr.range(of: pattern, options: .regularExpression) {
                let match = String(instr[range])
                
                // Números diretos
                if let num = Int(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    return max(1, min(num, 16))  // Limita entre 1 e 16 semanas
                }
                
                // Números por extenso
                let wordToNumber: [String: Int] = [
                    "uma": 1, "dois": 2, "duas": 2, "três": 3,
                    "quatro": 4, "cinco": 5, "seis": 6,
                    "sete": 7, "oito": 8
                ]
                
                for (word, num) in wordToNumber {
                    if match.contains(word) {
                        return num
                    }
                }
            }
        }
        
        // Fallback: 4 semanas (1 mês)
        return 4
    }
}

extension WeekBlueprint {
    var safeJsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
