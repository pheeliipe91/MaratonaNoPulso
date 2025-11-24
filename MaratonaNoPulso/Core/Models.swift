import Foundation

// MARK: - Plano Semanal (Para a WeeklyPlanView)
// Mudado para Decodable pois só precisamos LER da AI/JSON
struct WeeklyTrainingPlan: Decodable {
    let plan_name: String
    let workouts: [DailyWorkout]
    
    init() {
        self.plan_name = "Plano Padrão"
        self.workouts = []
    }
}

// MARK: - Treino Diário (Para a WeeklyPlanView)
struct DailyWorkout: Decodable, Identifiable {
    var id: String { "\(day)-\(workout_name)" }
    
    let day: Int
    let workout_name: String
    let workout_type: WorkoutType
    let duration_minutes: Int
    let distance_km: Double?
    let is_rest_day: Bool
    let segments: [WorkoutSegment]?
    
    // Opcional para não quebrar se a AI esquecer
    let instructions: String?
}

// MARK: - Plano Avulso da AI (Para a VoiceCoachView)
// Mudado para Decodable para aceitar nossas CodingKeys flexíveis sem erro
struct AIWorkoutPlan: Decodable {
    var workout_type: String
    var duration_minutes: Int
    var distance_km: Double?
    var pace_min_per_km: Double?
    var segments: [WorkoutSegment]?
    
    // Chaves flexíveis para "perdoar" a AI
    enum CodingKeys: String, CodingKey {
        case workout_type, type, activity_type
        case duration_minutes, duration, minutes, time
        case distance_km, distance, dist, kilometers
        case pace_min_per_km, pace, target_pace
        case segments, intervals, blocks
    }
    
    // O Decodificador Inteligente
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 1. Tenta ler o tipo de treino
        if let type = try? container.decode(String.self, forKey: .workout_type) {
            workout_type = type
        } else if let type = try? container.decode(String.self, forKey: .type) {
            workout_type = type
        } else {
            workout_type = "outdoor_run"
        }
        
        // 2. Tenta ler a duração
        if let dur = try? container.decode(Int.self, forKey: .duration_minutes) {
            duration_minutes = dur
        } else if let dur = try? container.decode(Int.self, forKey: .duration) {
            duration_minutes = dur
        } else {
            duration_minutes = 30
        }
        
        // 3. Opcionais
        distance_km = (try? container.decodeIfPresent(Double.self, forKey: .distance_km))
                   ?? (try? container.decodeIfPresent(Double.self, forKey: .distance))
        
        pace_min_per_km = (try? container.decodeIfPresent(Double.self, forKey: .pace_min_per_km))
                       ?? (try? container.decodeIfPresent(Double.self, forKey: .pace))
        
        // 4. Segmentos
        segments = (try? container.decodeIfPresent([WorkoutSegment].self, forKey: .segments))
                ?? (try? container.decodeIfPresent([WorkoutSegment].self, forKey: .intervals))
    }
    
    // Init manual para testes
    init(test: Bool) {
        self.workout_type = "outdoor_run"
        self.duration_minutes = 30
        self.distance_km = 5.0
        self.pace_min_per_km = 6.0
        self.segments = []
    }
}

// MARK: - Segmentos Compartilhados
struct WorkoutSegment: Decodable {
    let type: String
    let duration_minutes: Int
    
    enum CodingKeys: String, CodingKey {
        case type, segment_type
        case duration_minutes, duration, minutes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = (try? container.decode(String.self, forKey: .type)) ?? "work"
        
        if let dur = try? container.decode(Int.self, forKey: .duration_minutes) {
            duration_minutes = dur
        } else {
            duration_minutes = (try? container.decode(Int.self, forKey: .duration)) ?? 5
        }
    }
    
    // Init manual
    init(type: String, duration: Int) {
        self.type = type
        self.duration_minutes = duration
    }
}

// MARK: - Enum de Tipos (Pode continuar Codable pois é simples)
enum WorkoutType: String, Codable {
    case outdoor_run = "outdoor_run"
    case indoor_run = "indoor_run"
    case walk = "walk"
    case rest = "rest"
    case cross_training = "cross_training"
    
    var icon: String {
        switch self {
        case .outdoor_run: return "figure.run"
        case .indoor_run: return "figure.run.treadmill"
        case .walk: return "figure.walk"
        case .rest: return "bed.double.fill"
        case .cross_training: return "dumbbell.fill"
        }
    }
    
    static func from(string: String) -> WorkoutType {
        let normalized = string.lowercased()
        if normalized.contains("indoor") { return .indoor_run }
        if normalized.contains("walk") || normalized.contains("caminhada") { return .walk }
        if normalized.contains("rest") || normalized.contains("descanso") { return .rest }
        if normalized.contains("cross") { return .cross_training }
        return .outdoor_run
    }
}
