import Foundation
import HealthKit
import Combine

// MARK: - Models Locais
public struct DailyActivity: Identifiable, Equatable {
    public let id = UUID()
    public let day: String
    public let distance: Double
    public let date: Date
}

class HealthKitManager: ObservableObject {
    
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    
    @Published var isAuthorized: Bool = false
    @Published var weeklyDistance: Double = 0.0
    @Published var dailyHistory: [DailyActivity] = []
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Double = 0.0
    
    // ✅ Armazena o último treino para o "Centro de Inteligência"
    @Published var latestWorkout: HKWorkout?
    
    // 🆕 MÉTRICAS AVANÇADAS PARA CÁLCULO DE PACE REAL
    @Published var vo2Max: Double?  // VO2 máximo
    @Published var restingHeartRate: Double?  // FC em repouso
    @Published var recentWorkouts: [HKWorkout] = []  // Últimos 10 treinos
    
    init() {
        // Init vazio para evitar chamadas automáticas
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let allTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,  // 🆕
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: allTypes as? Set<HKSampleType>, read: allTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.fetchAllData()
                } else if let error = error {
                    print("Erro HealthKit: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func fetchAllData() {
        fetchWeeklyRunningDistance()
        fetchDailyHistory()
        fetchTodayMetrics()
        fetchLatestWorkout()
        fetchVO2Max()  // 🆕
        fetchRestingHeartRate()  // 🆕
        fetchRecentWorkouts()  // 🆕
    }
    
    // MARK: - Busca Treino Recente
    func fetchLatestWorkout() {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // ✅ Predicate: Apenas treinos dos últimos 7 dias (performance)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: .workoutType(), 
            predicate: predicate, 
            limit: 1, 
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            
            if let error = error {
                print("❌ Erro ao buscar workout: \(error.localizedDescription)")
                return
            }
            
            guard let workouts = samples as? [HKWorkout], let last = workouts.first else { 
                print("ℹ️ Nenhum treino recente encontrado")
                return 
            }
            
            DispatchQueue.main.async {
                self?.latestWorkout = last
                print("✅ Último treino carregado: \(last.startDate)")
            }
        }
        healthStore.execute(query)
    }
    
    // MARK: - Métricas de Hoje
    func fetchTodayMetrics() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // Passos
        let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            DispatchQueue.main.async { self.todaySteps = Int(steps) }
        }
        
        // Calorias
        let calQuery = HKStatisticsQuery(quantityType: calType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let cals = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
            DispatchQueue.main.async { self.todayCalories = cals }
        }
        
        healthStore.execute(stepQuery)
        healthStore.execute(calQuery)
    }
    
    // MARK: - Total Semanal
    func fetchWeeklyRunningDistance() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        let now = Date()
        let startOfWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            guard let sum = result?.sumQuantity() else { return }
            let km = sum.doubleValue(for: HKUnit.meter()) / 1000.0
            
            DispatchQueue.main.async { self?.weeklyDistance = km }
        }
        healthStore.execute(query)
    }
    
    // MARK: - Histórico Diário
    func fetchDailyHistory() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startWarning = calendar.date(byAdding: .day, value: -6, to: now)!
        let anchorDate = calendar.startOfDay(for: startWarning)
        let interval = DateComponents(day: 1)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { [weak self] _, result, error in
            guard let result = result else { return }
            var activities: [DailyActivity] = []
            
            result.enumerateStatistics(from: anchorDate, to: now) { statistics, stop in
                let meters = statistics.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0.0
                let km = meters / 1000.0
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE"
                let dayLabel = dateFormatter.string(from: statistics.startDate).uppercased()
                
                activities.append(DailyActivity(day: dayLabel, distance: km, date: statistics.startDate))
            }
            
            DispatchQueue.main.async {
                self?.dailyHistory = activities
            }
        }
        
        healthStore.execute(query)
    }

    // MARK: - Gravação de Treino (Versão iOS 17+ Builder)
    func saveCompletedWorkout(startTime: Date, durationMinutes: Double, distanceKm: Double, activityType: HKWorkoutActivityType = .running) {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())

        builder.beginCollection(withStart: startTime) { (success, error) in
            guard success else {
                print("❌ Erro ao iniciar builder: \(error?.localizedDescription ?? "")")
                return
            }

            let endTime = startTime.addingTimeInterval(durationMinutes * 60)
            
            // Criar amostras (Samples)
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
            
            let userWeightKg = 75.0 // Idealmente viria do perfil
            let estimatedKcal = userWeightKg * distanceKm * 1.036
            
            let totalEnergy = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedKcal)
            let totalDistance = HKQuantity(unit: .meter(), doubleValue: distanceKm * 1000)
            
            let energySample = HKCumulativeQuantitySample(type: energyType, quantity: totalEnergy, start: startTime, end: endTime)
            let distanceSample = HKCumulativeQuantitySample(type: distanceType, quantity: totalDistance, start: startTime, end: endTime)

            builder.add([energySample, distanceSample]) { (success, error) in
                guard success else { return }
                
                builder.endCollection(withEnd: endTime) { (success, error) in
                    guard success else { return }
                    
                    builder.finishWorkout { (workout, error) in
                        if let w = workout {
                            print("✅ Treino salvo: \(w.uuid)")
                            // Atualiza a UI na main thread
                            DispatchQueue.main.async {
                                self.fetchAllData()
                            }
                        } else {
                            print("❌ Falha ao finalizar treino: \(error?.localizedDescription ?? "")")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 🆕 MÉTRICAS AVANÇADAS PARA CÁLCULO REAL DE PACE
    
    func fetchVO2Max() {
        guard let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: vo2MaxType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                print("❌ Erro ao buscar VO2Max: \(error.localizedDescription)")
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                print("ℹ️ Nenhum VO2Max encontrado")
                return
            }
            
            let vo2 = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
            
            DispatchQueue.main.async {
                self?.vo2Max = vo2
                print("✅ VO2Max carregado: \(String(format: "%.1f", vo2)) ml/kg/min")
            }
        }
        healthStore.execute(query)
    }
    
    func fetchRestingHeartRate() {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        
        let last7Days = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: last7Days, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: restingHRType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { [weak self] _, result, error in
            if let error = error {
                print("❌ Erro ao buscar FC repouso: \(error.localizedDescription)")
                return
            }
            
            guard let avg = result?.averageQuantity() else {
                print("ℹ️ Nenhuma FC de repouso encontrada")
                return
            }
            
            let bpm = avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            DispatchQueue.main.async {
                self?.restingHeartRate = bpm
                print("✅ FC repouso carregada: \(String(format: "%.0f", bpm)) bpm")
            }
        }
        healthStore.execute(query)
    }
    
    func fetchRecentWorkouts() {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // Últimos 30 dias
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: predicate,
            limit: 10,  // Últimos 10 treinos
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                print("❌ Erro ao buscar treinos recentes: \(error.localizedDescription)")
                return
            }
            
            guard let workouts = samples as? [HKWorkout] else {
                print("ℹ️ Nenhum treino recente encontrado")
                return
            }
            
            DispatchQueue.main.async {
                self?.recentWorkouts = workouts
                print("✅ Treinos recentes carregados: \(workouts.count)")
            }
        }
        healthStore.execute(query)
    }
    
    // 🆕 CALCULA PACE MÉDIO REAL DOS ÚLTIMOS TREINOS
    func calculateAveragePace() -> String? {
        guard !recentWorkouts.isEmpty else { return nil }
        
        var totalSeconds: Double = 0
        var totalKm: Double = 0
        var validWorkouts = 0
        
        for workout in recentWorkouts {
            // Só considera corridas
            guard workout.workoutActivityType == .running else { continue }
            
            // Busca distância
            guard let distanceStat = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!),
                  let distance = distanceStat.sumQuantity()?.doubleValue(for: .meter()) else { continue }
            
            let distanceKm = distance / 1000.0
            
            // Ignora treinos muito curtos (< 1km) ou muito longos (> 30km)
            guard distanceKm >= 1.0 && distanceKm <= 30.0 else { continue }
            
            let durationSeconds = workout.duration
            let paceSecondsPerKm = durationSeconds / distanceKm
            
            // Ignora paces absurdos (< 3:00/km ou > 10:00/km)
            guard paceSecondsPerKm >= 180 && paceSecondsPerKm <= 600 else { continue }
            
            totalSeconds += durationSeconds
            totalKm += distanceKm
            validWorkouts += 1
        }
        
        guard validWorkouts > 0 && totalKm > 0 else { return nil }
        
        let avgPaceSeconds = totalSeconds / totalKm
        let minutes = Int(avgPaceSeconds / 60)
        let seconds = Int(avgPaceSeconds.truncatingRemainder(dividingBy: 60))
        
        let paceString = String(format: "%d:%02d", minutes, seconds)
        print("📊 Pace médio calculado (últimos \(validWorkouts) treinos): \(paceString)/km")
        
        return paceString
    }
}
