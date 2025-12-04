import Foundation

// MARK: - Helpers de Serialização Segura
extension Encodable {
    var safeJsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// A lógica de 'signature' foi movida para Models.swift para evitar conflitos.
// Este arquivo agora serve apenas para helpers genéricos.
