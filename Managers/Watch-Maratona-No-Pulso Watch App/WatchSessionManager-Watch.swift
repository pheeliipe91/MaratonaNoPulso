//
//  WatchSessionManager.swift
//  Watch-Maratona-No-Pulso Watch App
//
//  Created by Phelipe de Oliveira Xavier on 24/11/25.
//

import WatchConnectivity
import SwiftUI
import Combine
import WorkoutKit
import HealthKit
import UserNotifications

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var receivedWorkout: String = "Aguardando treino..."
    @Published var isReachable: Bool = false
    
    override init() {
        super.init()
        activateSession()
        requestNotificationPermission()
    }
    
    func activateSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("Watch: Sessao WCSession ativada")
        } else {
            print("Watch: WCSession nao e suportado")
        }
    }
    
    // MARK: - Notificacoes
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Watch: Permissao de notificacao concedida")
            } else if let error = error {
                print("Watch: Erro ao solicitar permissao: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Watch: Erro ao enviar notificacao: \(error.localizedDescription)")
            } else {
                print("Watch: Notificacao enviada com sucesso")
            }
        }
    }
    
    // MARK: - WCSessionDelegate Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("Watch: Sessao ativada - Reachable: \(session.isReachable)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("Watch: Reachability mudou para: \(session.isReachable)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("Watch: Mensagem recebida: \(message)")
        
        if let action = message["action"] as? String, action == "scheduleWorkout" {
            Task {
                let success = await self.scheduleWorkoutFromMessage(message)
                replyHandler(["success": success])
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("Watch: Mensagem recebida: \(message)")
        
        if let workout = message["workout"] as? String {
            DispatchQueue.main.async {
                self.receivedWorkout = workout
                print("Watch: Treino atualizado - \(workout)")
            }
        }
        
        if let workoutData = message["workoutData"] as? [String: Any] {
            DispatchQueue.main.async {
                self.handleWorkoutData(workoutData)
            }
        }
        
        if let action = message["action"] as? String, action == "scheduleWorkout" {
            Task {
                await self.scheduleWorkoutFromMessage(message)
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        print("Watch: UserInfo recebido: \(userInfo)")
        
        if let action = userInfo["action"] as? String, action == "scheduleWorkout" {
            Task {
                await self.scheduleWorkoutFromMessage(userInfo)
            }
        }
    }
    
    // MARK: - Agendar Workout no Watch
    
    @MainActor
    private func scheduleWorkoutFromMessage(_ message: [String: Any]) async -> Bool {
        guard let name = message["name"] as? String,
              let duration = message["duration"] as? Int,
              let typeString = message["type"] as? String,
              let dateTimestamp = message["date"] as? TimeInterval else {
            print("Watch: Dados incompletos para agendar treino")
            return false
        }
        
        let distance = message["distance"] as? Double ?? 0
        let workoutDate = Date(timeIntervalSince1970: dateTimestamp)
        
        // Determinar tipo de atividade
        let activityType: HKWorkoutActivityType
        let locationType: HKWorkoutSessionLocationType
        
        switch typeString {
        case "outdoor_run":
            activityType = .running
            locationType = .outdoor
        case "indoor_run":
            activityType = .running
            locationType = .indoor
        case "walk":
            activityType = .walking
            locationType = .outdoor
        case "cross_training":
            activityType = .crossTraining
            locationType = .indoor
        default:
            activityType = .running
            locationType = .outdoor
        }
        
        // Criar bloco de treino
        let goal: WorkoutGoal
        if distance > 0 {
            goal = .distance(distance, .kilometers)
        } else {
            let seconds = Double(duration) * 60
            goal = .time(seconds, .seconds)
        }
        
        let step = IntervalStep(.work, goal: goal)
        let block = IntervalBlock(steps: [step], iterations: 1)
        
        // Criar CustomWorkout
        let customWorkout = CustomWorkout(
            activity: activityType,
            location: locationType,
            displayName: name,
            warmup: nil,
            blocks: [block],
            cooldown: nil
        )
        
        // Agendar no Watch
        var dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: workoutDate
        )
        dateComponents.hour = 7
        dateComponents.minute = 0
        
        do {
            let workoutPlan = WorkoutKit.WorkoutPlan(.custom(customWorkout))
            try await WorkoutScheduler.shared.schedule(workoutPlan, at: dateComponents)
            
            DispatchQueue.main.async {
                self.receivedWorkout = "Treino agendado: \(name)"
                
                // Enviar notificacao local
                self.sendLocalNotification(
                    title: "Treino Recebido!",
                    body: "\(name) foi adicionado ao app Exercicio. Abra Biblioteca > Custom para ver."
                )
            }
            print("Watch: Treino agendado com sucesso - \(name)")
            return true
        } catch {
            print("Watch: Erro ao agendar treino - \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.sendLocalNotification(
                    title: "Erro no Treino",
                    body: "Nao foi possivel agendar: \(name)"
                )
            }
            return false
        }
    }
    
    private func handleWorkoutData(_ data: [String: Any]) {
        if let name = data["name"] as? String,
           let distance = data["distance"] as? Double,
           let duration = data["duration"] as? TimeInterval {
            
            let workoutText = "\(name)\nDistancia: \(distance)km\nDuracao: \(duration)s"
            self.receivedWorkout = workoutText
        }
    }
    
    // Enviar confirmacao para o iPhone
    func sendConfirmationToPhone() {
        if WCSession.default.isReachable {
            let message = ["confirmation": "Treino recebido no Watch!"]
            WCSession.default.sendMessage(message, replyHandler: { response in
                print("Watch: Confirmacao enviada - \(response)")
            }, errorHandler: { error in
                print("Watch: Erro ao enviar confirmacao: \(error)")
            })
        }
    }
}
