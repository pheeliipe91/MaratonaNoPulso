import WatchConnectivity
import SwiftUI
import Combine  // ← ADICIONAR ESTA LINHA

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isWatchReachable: Bool = false
    @Published var lastConfirmation: String = ""
    
    override init() {
        super.init()
        activateSession()
    }
    
    func activateSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("iPhone: Sessão WCSession ativada")
        }
    }
    
    // MARK: - WCSessionDelegate Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            // NO iOS usamos isWatchAppInstalled, no Watch isso não existe
            self.isWatchReachable = session.isReachable
            print("iPhone: Sessão ativada - Reachable: \(session.isReachable)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("iPhone: Sessão tornou-se inativa")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("iPhone: Sessão desativada")
        WCSession.default.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("iPhone: Estado do Watch mudou - Reachable: \(session.isReachable)")
        }
    }
    #endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("iPhone: Reachability mudou para: \(session.isReachable)")
        }
    }
    
    // Receber mensagens do Watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("iPhone: Mensagem recebida do Watch: \(message)")
        
        // ✅ Validação de dados recebidos
        guard !message.isEmpty else {
            print("iPhone: Mensagem vazia ignorada")
            return
        }
        
        if let confirmation = message["confirmation"] as? String {
            // ✅ Sanitização básica
            let sanitized = confirmation.prefix(200) // Limita tamanho
            DispatchQueue.main.async {
                self.lastConfirmation = String(sanitized)
                print("iPhone: Confirmação recebida - \(sanitized)")
            }
        }
    }
    
    // MARK: - Enviar Dados para o Watch
    
    func sendWorkoutToWatch(_ workout: String) {
        guard WCSession.default.isReachable else {
            print("iPhone: Watch não está acessível")
            return
        }
        
        let message = ["workout": workout]
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            print("iPhone: Resposta do Watch: \(response)")
        }, errorHandler: { error in
            print("iPhone: Erro ao enviar para Watch: \(error.localizedDescription)")
        })
    }
    
    func sendWorkoutDataToWatch(name: String, distance: Double, duration: TimeInterval) {
        guard WCSession.default.isReachable else {
            print("iPhone: Watch não está acessível")
            return
        }
        
        let workoutData: [String: Any] = [
            "workoutData": [
                "name": name,
                "distance": distance,
                "duration": duration
            ]
        ]
        
        WCSession.default.sendMessage(workoutData, replyHandler: { response in
            print("iPhone: Workout data enviado - Resposta: \(response)")
        }, errorHandler: { error in
            print("iPhone: Erro ao enviar workout data: \(error.localizedDescription)")
        })
    }
    
    // Método para verificar o estado da conexão
    func checkConnectionStatus() -> String {
        let session = WCSession.default
        #if os(iOS)
        if !session.isWatchAppInstalled {
            return "Watch App não instalado"
        } else if !session.isReachable {
            return "Watch não acessível"
        } else {
            return "Conectado e pronto"
        }
        #else
        return session.isReachable ? "Conectado" : "Desconectado"
        #endif
    }
}
