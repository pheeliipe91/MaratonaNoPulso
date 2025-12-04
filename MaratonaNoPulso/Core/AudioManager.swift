import Foundation
import AVFoundation
import Speech
import Combine
import UIKit  // ✅ Necessário para UIApplication

class AudioManager: ObservableObject {
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isListening = false
    @Published var transcribedText = ""
    
    init() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
        
        // ✅ Observa quando o app vai para background e para a gravação
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAppDidEnterBackground() {
        if isListening {
            stopRecording()
        }
    }

    // 🔥 ADICIONE estas funções:
    func startRecording() {
        if isListening {
            stopRecording()
        }
        startTranscription()
    }
    
    func stopRecording() {
        stopTranscription()
    }
    
    func toggleRecording() {
        if isListening {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // Mantenha as funções privadas existentes:
    private func startTranscription() {
        guard !isListening else { return }
        
        transcribedText = ""
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // ✅ Configuração otimizada para Speech Recognition
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // ✅ Preferência de qualidade/latência (evita overload)
            try audioSession.setPreferredIOBufferDuration(0.02) // 20ms buffer
        } catch {
            print("DEBUG: Falha ao configurar sessão de áudio: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }
            
            if error != nil {
                self.stopRecording()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // ✅ Aumentado de 1024 para 4096 para evitar overload do audio thread
        // Buffer maior = menos callbacks = menos trabalho para o sistema
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            self.isListening = true
            print("DEBUG: Transcrição iniciada.")
        } catch {
            print("DEBUG: Erro ao iniciar audioEngine: \(error)")
        }
    }
    
    private func stopTranscription() {
        guard isListening else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask = nil
        recognitionRequest = nil
        
        self.isListening = false
        print("DEBUG: Transcrição parada. Texto: '\(transcribedText)'")
    }
}
