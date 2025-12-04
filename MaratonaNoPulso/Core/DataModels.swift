import Foundation
import SwiftData

// MARK: - Perfil do Atleta (A Memória da AI)
@Model
class UserProfile {
    var name: String
    var age: Int
    var weight: Double
    var experienceLevel: String // "Iniciante", "Intermediário", "Avançado"
    var mainGoal: String // "Maratona em Dezembro", "Perder peso", "Sub 20min nos 5k"
    var weeklyFrequency: Int // Quantas vezes quer treinar por semana
    
    init(name: String, age: Int, weight: Double, experienceLevel: String, mainGoal: String, weeklyFrequency: Int) {
        self.name = name
        self.age = age
        self.weight = weight
        self.experienceLevel = experienceLevel
        self.mainGoal = mainGoal
        self.weeklyFrequency = weeklyFrequency
    }
}

// MARK: - Plano Salvo (A "Pasta" do Treino)
@Model
class SavedPlan {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var goalDescription: String // O que o user pediu (ex: "Tiro de 5k")
    
    // Relacionamento: Um plano tem vários treinos. Se apagar o plano, apaga os treinos.
    @Relationship(deleteRule: .cascade) var workouts: [SavedWorkout] = []
    
    init(name: String, goalDescription: String, workouts: [SavedWorkout] = []) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.goalDescription = goalDescription
        self.workouts = workouts
    }
}

// MARK: - Treino Salvo (O Detalhe do Dia)
@Model
class SavedWorkout {
    var id: UUID
    var day: Int
    var name: String
    var type: String // "outdoor_run", "rest", etc.
    var durationMinutes: Int
    var distanceKm: Double
    var instructions: String
    var isRestDay: Bool
    
    // Para simplificar, guardamos os segmentos (aquecimento, tiros) como texto JSON.
    // É mais seguro do que criar tabelas complexas para dados que só precisamos ler.
    var rawSegmentsJSON: String
    
    init(day: Int, name: String, type: String, duration: Int, distance: Double, instructions: String, isRest: Bool, segmentsJSON: String) {
        self.id = UUID()
        self.day = day
        self.name = name
        self.type = type
        self.durationMinutes = duration
        self.distanceKm = distance
        self.instructions = instructions
        self.isRestDay = isRest
        self.rawSegmentsJSON = segmentsJSON
    }
}
