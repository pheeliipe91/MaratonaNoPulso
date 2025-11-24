import Foundation

// Modelo para o plano de treino
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

struct WorkoutSegment: Codable {
    let type: String
    let duration_minutes: Int
    let intensity: String
    let description: String
}
