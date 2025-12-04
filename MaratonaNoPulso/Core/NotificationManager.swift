import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    init() {
        requestPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("🔔 Notificações permitidas")
            } else if let error = error {
                print("❌ Erro nas notificações: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleWorkoutReminder(for workout: DailyPlan) {
        let content = UNMutableNotificationContent()
        content.title = "Treino de Amanhã: \(workout.title)"
        content.body = workout.description
        content.sound = .default
        
        // Lógica simples: Agendar para as 7:00 AM do dia seguinte (Mock para MVP)
        // Num app real, usaríamos a data do 'suggestedDay' se fosse uma data real
        
        // Para teste agora: Agendar para daqui 10 segundos
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        
        let request = UNNotificationRequest(identifier: workout.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Função para agendar lembrete diário geral
    func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Foco na Maratona 🏃"
        content.body = "Não esqueça de conferir seu plano de hoje."
        
        var dateComponents = DateComponents()
        dateComponents.hour = 8 // 8:00 da manhã
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
