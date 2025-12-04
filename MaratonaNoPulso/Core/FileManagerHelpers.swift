import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var content: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // ✅ ADICIONADO: Suporte a CSV e Texto Separado por Vírgula
        let supportedTypes: [UTType] = [
            .pdf,
            .text,
            .plainText,
            .utf8PlainText,
            .commaSeparatedText, // CSV
            .tabSeparatedText    // TSV
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Feedback visual de carregamento poderia ser inserido aqui
            print("Arquivo selecionado: \(url.lastPathComponent)")
            
            if url.pathExtension.lowercased() == "pdf" {
                parent.content = extractTextFromPDF(url: url)
            } else {
                // Tenta ler como texto (funciona para TXT, CSV, MD, JSON)
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    parent.content = text
                } catch {
                    // Fallback: Tenta ler com codificação Windows/Latin se falhar
                    if let text = try? String(contentsOf: url, encoding: .windowsCP1252) {
                        parent.content = text
                    } else {
                        parent.content = "Erro: Não foi possível ler o texto deste arquivo."
                    }
                }
            }
        }
        
        private func extractTextFromPDF(url: URL) -> String {
            guard let pdfDocument = PDFDocument(url: url) else { return "" }
            var fullText = ""
            let pageCount = pdfDocument.pageCount
            
            for i in 0..<pageCount {
                if let page = pdfDocument.page(at: i), let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
            return fullText
        }
    }
}
