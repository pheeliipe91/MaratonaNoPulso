import Foundation
import AVFoundation
import Speech
import Combine

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
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
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
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
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
