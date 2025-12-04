import Foundation

// MARK: - Enums Estruturais
enum SegmentRole: String, Codable, CaseIterable, Identifiable, Equatable {
    case warmup = "warmup"
    case work = "work"
    case recovery = "recovery"
    case cooldown = "cooldown"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .warmup: return "Aquecimento"
        case .work: return "Esforço"
        case .recovery: return "Recuperação"
        case .cooldown: return "Desaquecimento"
        }
    }
}

enum GoalType: String, Codable, CaseIterable, Identifiable, Equatable {
    case time = "time"
    case distance = "distance"
    case open = "open"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .time: return "Tempo"
        case .distance: return "Distância"
        case .open: return "Livre"
        }
    }
}

// MARK: - Workout Segment (Enterprise Edition)
struct WorkoutSegment: Codable, Identifiable, Hashable, Equatable {
    var id = UUID()
    var role: SegmentRole
    var goalType: GoalType
    
    var durationMinutes: Double?
    var distanceKm: Double?
    var intensity: String
    var targetPaceMin: String?
    var targetPaceMax: String?
    var reps: Int?
    
    enum CodingKeys: String, CodingKey {
        case role, goalType, durationMinutes, distanceKm, intensity, targetPaceMin, targetPaceMax, reps
    }
    
    // Init Robusto: Aceita todos os parâmetros opcionais
    init(role: SegmentRole = .work,
         goalType: GoalType = .time,
         durationMinutes: Double? = nil,
         distanceKm: Double? = nil,
         intensity: String = "Moderado",
         targetPaceMin: String? = nil,
         targetPaceMax: String? = nil,
         reps: Int? = nil) {
        
        self.role = role
        self.goalType = goalType
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.intensity = intensity
        self.targetPaceMin = targetPaceMin
        self.targetPaceMax = targetPaceMax
        self.reps = reps
    }
    
    // Decodificação Tolerante
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let roleString = try? container.decode(String.self, forKey: .role) {
            self.role = SegmentRole(rawValue: roleString.lowercased()) ?? .work
        } else { self.role = .work }
        
        if let goalString = try? container.decode(String.self, forKey: .goalType) {
            self.goalType = GoalType(rawValue: goalString.lowercased()) ?? .time
        } else { self.goalType = .time }
        
        self.durationMinutes = try? container.decodeIfPresent(Double.self, forKey: .durationMinutes)
        self.distanceKm = try? container.decodeIfPresent(Double.self, forKey: .distanceKm)
        self.intensity = (try? container.decodeIfPresent(String.self, forKey: .intensity)) ?? "Moderado"
        self.targetPaceMin = try? container.decodeIfPresent(String.self, forKey: .targetPaceMin)
        self.targetPaceMax = try? container.decodeIfPresent(String.self, forKey: .targetPaceMax)
        self.reps = try? container.decodeIfPresent(Int.self, forKey: .reps)
    }
    
    var intensityColor: String {
        switch role {
        case .warmup, .cooldown: return "Blue"
        case .recovery: return "Green"
        case .work: return (targetPaceMin != nil) ? "Red" : "Orange"
        }
    }
    
    var summary: String {
        switch goalType {
        case .time: return "\(String(format: "%.0f", durationMinutes ?? 0)) min"
        case .distance: return "\(String(format: "%.2f", distanceKm ?? 0)) km"
        case .open: return "Livre"
        }
    }
}

// MARK: - App Models
struct DailyPlan: Identifiable, Codable, Equatable {
    let id: UUID
    let day: String
    var activityType: String
    var title: String
    var description: String
    var structure: String?
    var isCompleted: Bool
    
    var sourceIcon: String?
    var sourceLabel: String?
    var safetyBadge: String?
    var coachTips: String?
    var cyclePhase: String?
    var cycleTarget: String?
    var planColor: String?
    var rawInstructionText: String?
    var workoutReasoning: String?
    var isArchived: Bool = false
    
    // 🆕 Parâmetros de Força
    var strengthParams: StrengthParameters?
    
    // 🆕 Metadados de Hierarquia
    var weekNumber: Int?           // Qual semana pertence
    var parentPlanId: UUID?        // ID do plano pai
    
    init(id: UUID = UUID(), day: String, activityType: String, title: String, description: String, structure: String? = nil, isCompleted: Bool = false, sourceIcon: String? = "waveform.path.ecg", sourceLabel: String? = "AI Generated", safetyBadge: String? = nil, coachTips: String? = nil, cyclePhase: String? = nil, cycleTarget: String? = nil, planColor: String? = nil, rawInstructionText: String? = nil, workoutReasoning: String? = nil, isArchived: Bool = false, strengthParams: StrengthParameters? = nil, weekNumber: Int? = nil, parentPlanId: UUID? = nil) {
        self.id = id
        self.day = day
        self.activityType = activityType
        self.title = title
        self.description = description
        self.structure = structure
        self.isCompleted = isCompleted
        self.sourceIcon = sourceIcon
        self.sourceLabel = sourceLabel
        self.safetyBadge = safetyBadge
        self.coachTips = coachTips
        self.cyclePhase = cyclePhase
        self.cycleTarget = cycleTarget
        self.planColor = planColor
        self.rawInstructionText = rawInstructionText
        self.workoutReasoning = workoutReasoning
        self.isArchived = isArchived
        self.strengthParams = strengthParams
        self.weekNumber = weekNumber
        self.parentPlanId = parentPlanId
    }
    
    var signature: WorkoutSignature {
        let estimatedDur = self.structure != nil ? 45 : 30
        return WorkoutSignature(type: self.activityType, duration: estimatedDur, instructions: self.rawInstructionText ?? self.description)
    }
    
    static func == (lhs: DailyPlan, rhs: DailyPlan) -> Bool { lhs.id == rhs.id }
}

struct AIWorkoutPlan: Codable, Equatable, Identifiable {
    var id: UUID { UUID() }
    let title: String
    let description: String?
    let distance: Double
    let duration: Int
    let type: String
    let suggestedDay: String?
    let cyclePhase: String?
    let cycleTarget: String?
    let rawInstructionText: String?
    let workoutReasoning: String?
    let segments: [WorkoutSegment]?
    let safetyWarning: String?
    let zoneFocus: String?
    let difficultyRating: String?
    
    // 🆕 Novos campos
    let weekNumber: Int?           // Qual semana (1, 2, 3...)
    let strengthParams: StrengthParameters?  // Parâmetros de força
    
    var signature: WorkoutSignature {
        WorkoutSignature(type: self.type, duration: self.duration, instructions: self.rawInstructionText)
    }
}

struct CyclePhase: Codable, Equatable, Identifiable {
    var id: UUID { UUID() }
    let phaseName: String
    let duration: String
    let focus: String
}

struct AIUserProfile: Codable, Equatable {
    var name: String
    var experienceLevel: String
    var goal: String
    var daysPerWeek: Int
    var currentDistance: Double
}

// MARK: - Análise Pós-Treino (Mova para cá para ficar visível globalmente)
struct PostWorkoutAnalysis: Codable, Equatable {
    let analysisSummary: String
    let recoveryScore: String
    let suggestedAction: String
    let coachComment: String
}

// MARK: - Assinatura de Treino (Para evitar duplicatas)
struct WorkoutSignature: Hashable, Equatable {
    let type: String
    let duration: Int
    let instructions: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(duration)
        hasher.combine(instructions ?? "")
    }
}

// MARK: - 🆕 HIERARQUIA DE PLANOS (Pastas Organizadas)
struct TrainingPlan: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String              // "Meia Maratona - 8 Semanas"
    let goal: String               // "Meia Maratona"
    let totalWeeks: Int            // 8
    let totalWorkouts: Int         // 56
    let createdAt: Date
    var weeks: [TrainingWeek]      // Array de semanas
    
    init(id: UUID = UUID(), name: String, goal: String, totalWeeks: Int, totalWorkouts: Int, createdAt: Date = Date(), weeks: [TrainingWeek] = []) {
        self.id = id
        self.name = name
        self.goal = goal
        self.totalWeeks = totalWeeks
        self.totalWorkouts = totalWorkouts
        self.createdAt = createdAt
        self.weeks = weeks
    }
}

struct TrainingWeek: Identifiable, Codable, Equatable {
    let id: UUID
    let weekNumber: Int            // 1, 2, 3...
    let phaseName: String          // "Base", "Construção", "Pico"
    let focus: String              // "Aeróbico", "Resistência"
    var workouts: [DailyPlan]      // Treinos da semana
    
    init(id: UUID = UUID(), weekNumber: Int, phaseName: String, focus: String, workouts: [DailyPlan] = []) {
        self.id = id
        self.weekNumber = weekNumber
        self.phaseName = phaseName
        self.focus = focus
        self.workouts = workouts
    }
}

// MARK: - 🆕 PARÂMETROS DE TREINO DE FORÇA
struct StrengthParameters: Codable, Equatable {
    let sets: Int?                 // Séries
    let reps: String?              // "10-12" ou "15"
    let restSeconds: Int?          // Descanso entre séries
    let exercises: [String]?       // ["Agachamento", "Lunges"]
    let notes: String?             // Observações
}
