import Foundation

// MARK: - Plano Semanal (Para a WeeklyPlanView)
struct WeeklyTrainingPlan: Codable {
    let plan_name: String
    let workouts: [DailyWorkout]
    
    // Init padrão para evitar erros
    init() {
        self.plan_name = "Plano Padrão"
        self.workouts = []
    }
}

// MARK: - Treino Diário (Para a WeeklyPlanView)
struct DailyWorkout: Codable, Identifiable {
    var id: String { "\(day)-\(workout_name)" }
    
    let day: Int
    let workout_name: String
    let workout_type: WorkoutType
    let duration_minutes: Int
    let distance_km: Double?
    let is_rest_day: Bool
    let segments: [WorkoutSegment]?
    
    // ⚠️ IMPORTANTE: Opcional (?) para não quebrar se a AI esquecer
    let instructions: String?
}

// MARK: - Plano Avulso da AI (Para a VoiceCoachView)
// Renomeado para AIWorkoutPlan para não conflitar com a Apple
struct AIWorkoutPlan: Codable {
    let workout_type: String
    let duration_minutes: Int
    let distance_km: Double?
    let pace_min_per_km: Double?
    let segments: [WorkoutSegment]?
    
    // Init de segurança
    init(error: String) {
        self.workout_type = "outdoor_run"
        self.duration_minutes = 30
        self.distance_km = 5.0
        self.pace_min_per_km = 6.0
        self.segments = []
    }
}

// MARK: - Segmentos Compartilhados
struct WorkoutSegment: Codable {
    let type: String
    let duration_minutes: Int
}

// MARK: - Enum de Tipos
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
    
    // Helper para converter string solta da AI em Enum
    static func from(string: String) -> WorkoutType {
        let normalized = string.lowercased()
        if normalized.contains("indoor") { return .indoor_run }
        if normalized.contains("walk") || normalized.contains("caminhada") { return .walk }
        if normalized.contains("rest") || normalized.contains("descanso") { return .rest }
        if normalized.contains("cross") { return .cross_training }
        return .outdoor_run
    }
}
