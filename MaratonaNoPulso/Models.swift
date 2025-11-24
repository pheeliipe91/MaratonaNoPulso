import Foundation

// MARK: - Plano Semanal de Treinos
struct WeeklyTrainingPlan: Codable {
    let plan_name: String
    let goal_description: String
    let total_days: Int
    let workouts: [DailyWorkout]
    let needsMoreInfo: String?
    
    init(needsMoreInfo: String) {
        self.plan_name = ""
        self.goal_description = ""
        self.total_days = 0
        self.workouts = []
        self.needsMoreInfo = needsMoreInfo
    }
}

// MARK: - Treino Diário
struct DailyWorkout: Codable, Identifiable {
    var id: String { "\(day)-\(workout_name)" }
    
    let day: Int // Dia 1, 2, 3...
    let workout_name: String // "Corrida Leve - Dia 1"
    let workout_type: WorkoutType
    let duration_minutes: Int
    let distance_km: Double?
    let pace_min_per_km: Double?
    let is_rest_day: Bool
    let instructions: String
    let segments: [WorkoutSegment]?
}

// MARK: - Tipo de Treino
enum WorkoutType: String, Codable {
    case outdoor_run = "outdoor_run"
    case indoor_run = "indoor_run"
    case walk = "walk"
    case rest = "rest"
    case cross_training = "cross_training"
    
    var displayName: String {
        switch self {
        case .outdoor_run: return "Corrida Outdoor"
        case .indoor_run: return "Corrida Indoor"
        case .walk: return "Caminhada"
        case .rest: return "Descanso"
        case .cross_training: return "Treino Cruzado"
        }
    }
    
    var systemImage: String {
        switch self {
        case .outdoor_run: return "figure.run"
        case .indoor_run: return "figure.run.treadmill"
        case .walk: return "figure.walk"
        case .rest: return "bed.double"
        case .cross_training: return "figure.strengthtraining.traditional"
        }
    }
}

// MARK: - Segmento do Treino
struct WorkoutSegment: Codable {
    let type: String // "warmup", "main", "cooldown", "interval"
    let duration_minutes: Int
    let intensity: String // "easy", "moderate", "hard"
    let description: String
    let target_pace: Double? // pace em min/km
}

// MARK: - Modelo Legado (para compatibilidade)
struct WorkoutPlan: Codable {
    let workout_type: String
    let duration_minutes: Int
    let calories_goal: Int?
    let distance_km: Double?
    let pace_min_per_km: Double?
    let heart_rate_zones: HeartRateZones?
    let segments: [WorkoutSegment]?
    let needsMoreInfo: String?
    
    init(needsMoreInfo: String) {
        self.workout_type = ""
        self.duration_minutes = 0
        self.calories_goal = nil
        self.distance_km = nil
        self.pace_min_per_km = nil
        self.heart_rate_zones = nil
        self.segments = nil
        self.needsMoreInfo = needsMoreInfo
    }
}

struct HeartRateZones: Codable {
    let warm_up: String
    let main_set: String
    let cool_down: String
}
