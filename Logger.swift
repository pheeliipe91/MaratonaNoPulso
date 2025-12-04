import Foundation
import os.log

/// Sistema de Logging Centralizado para Produção
/// 
/// Uso:
/// ```
/// AppLogger.info("Usuário iniciou treino")
/// AppLogger.error("Falha na API", error: error)
/// AppLogger.analytics("workout_completed", params: ["distance": 5.2])
/// ```
struct AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.maratonanopulso"
    
    // Categorias de Log
    private static let general = OSLog(subsystem: subsystem, category: "general")
    private static let network = OSLog(subsystem: subsystem, category: "network")
    private static let audio = OSLog(subsystem: subsystem, category: "audio")
    private static let analytics = OSLog(subsystem: subsystem, category: "analytics")
    private static let healthKit = OSLog(subsystem: subsystem, category: "healthkit")
    
    // MARK: - Níveis de Log
    
    static func info(_ message: String, category: LogCategory = .general) {
        os_log("%{public}@", log: category.osLog, type: .info, message)
    }
    
    static func debug(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        os_log("%{public}@", log: category.osLog, type: .debug, message)
        #endif
    }
    
    static func error(_ message: String, error: Error? = nil, category: LogCategory = .general) {
        let fullMessage = error != nil ? "\(message) - \(error!.localizedDescription)" : message
        os_log("%{public}@", log: category.osLog, type: .error, fullMessage)
    }
    
    static func fault(_ message: String, category: LogCategory = .general) {
        os_log("%{public}@", log: category.osLog, type: .fault, message)
    }
    
    // MARK: - Analytics Events
    
    /// Registra evento de analytics (pode integrar com Firebase/Mixpanel depois)
    static func analytics(_ eventName: String, params: [String: Any]? = nil) {
        let paramsString = params?.description ?? ""
        os_log("EVENT: %{public}@ | %{public}@", log: analytics, type: .info, eventName, paramsString)
        
        // TODO: Integrar com serviço de analytics real
        // Firebase.Analytics.logEvent(eventName, parameters: params)
    }
}

// MARK: - Categorias
enum LogCategory {
    case general
    case network
    case audio
    case analytics
    case healthKit
    
    var osLog: OSLog {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.maratonanopulso"
        switch self {
        case .general: return OSLog(subsystem: subsystem, category: "general")
        case .network: return OSLog(subsystem: subsystem, category: "network")
        case .audio: return OSLog(subsystem: subsystem, category: "audio")
        case .analytics: return OSLog(subsystem: subsystem, category: "analytics")
        case .healthKit: return OSLog(subsystem: subsystem, category: "healthkit")
        }
    }
}
