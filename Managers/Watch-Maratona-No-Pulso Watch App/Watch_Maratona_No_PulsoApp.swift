//
//  Watch_Maratona_No_PulsoApp.swift
//  Watch-Maratona-No-Pulso Watch App
//
//  Created by Phelipe de Oliveira Xavier on 24/11/25.
//

import SwiftUI

@main
struct Watch_Maratona_No_Pulso_Watch_AppApp: App {
    @StateObject private var sessionManager = WatchSessionManager()
    
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Image(systemName: "figure.run")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                Text("Maratona no Pulso")
                    .font(.headline)
                
                HStack {
                    Circle()
                        .fill(sessionManager.isReachable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(sessionManager.isReachable ? "iPhone conectado" : "Desconectado")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                Text(sessionManager.receivedWorkout)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Text("Envie treinos pelo iPhone")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}
