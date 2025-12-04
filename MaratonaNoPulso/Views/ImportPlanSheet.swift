import SwiftUI

struct ImportPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var importedText: String
    var onCommit: () -> Void
    
    @State private var textInput: String = ""
    @State private var showDocumentPicker = false
    @State private var selectedTab = 1 // Começa na aba Arquivo (Foco do redesign)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fundo Global
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Customizado
                    HStack {
                        Text("IMPORT DATA")
                            .font(.headline).bold().tracking(2)
                            .foregroundStyle(.white)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding()
                    
                    // Tabs
                    HStack(spacing: 0) {
                        TabButton(title: "ARQUIVO / PDF", icon: "doc.text.viewfinder", isSelected: selectedTab == 1) { selectedTab = 1 }
                        TabButton(title: "COLAR TEXTO", icon: "clipboard", isSelected: selectedTab == 0) { selectedTab = 0 }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    if selectedTab == 1 {
                        FileImportView()
                            .transition(.move(edge: .leading))
                    } else {
                        TextInputView()
                            .transition(.move(edge: .trailing))
                    }
                    
                    Spacer()
                    
                    // Botão de Ação Principal
                    Button(action: processImport) {
                        HStack {
                            Text("PROCESSAR DADOS")
                                .font(.headline.bold())
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(textInput.isEmpty ? Color.gray : Color.neonGreen)
                        .cornerRadius(16)
                    }
                    .disabled(textInput.isEmpty)
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(content: $textInput)
            }
        }
    }
    
    // MARK: - Lógica
    func processImport() {
        if !textInput.isEmpty {
            // Adiciona contexto para a AI saber a origem
            importedText = """
            [CONTEXTO: IMPORTAÇÃO DE ARQUIVO/PLANILHA]
            O usuário importou os seguintes dados brutos de treino:
            ---
            \(textInput)
            ---
            """
            onCommit()
            dismiss()
        }
    }
    
    // MARK: - Subviews
    
    func FileImportView() -> some View {
        VStack(spacing: 30) {
            // Área de Upload
            Button {
                showDocumentPicker = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .background(Color.white.opacity(0.03))
                    
                    VStack(spacing: 15) {
                        Circle()
                            .fill(Color.electricBlue.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.electricBlue)
                            )
                        
                        Text("Toque para buscar")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("PDF, CSV ou Texto")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(height: 250)
            .padding(.horizontal)
            
            // Dicas de Compatibilidade
            VStack(alignment: .leading, spacing: 15) {
                Label("SUPORTE", systemImage: "info.circle")
                    .font(.caption).bold().tracking(2)
                    .foregroundStyle(.gray)
                
                HStack(spacing: 20) {
                    FormatBadge(icon: "doc.fill", label: "PDF")
                    FormatBadge(icon: "tablecells.fill", label: "CSV")
                    FormatBadge(icon: "doc.text.fill", label: "TXT")
                }
                
                // Instrução sobre Google Sheets/Excel
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    
                    Text("Para **Google Sheets** ou **Excel**: Salve/Exporte sua planilha como **PDF** ou **CSV** antes de importar.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                // Status do Arquivo
                if !textInput.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Arquivo lido com sucesso!")
                            .font(.subheadline).bold()
                            .foregroundStyle(.white)
                        Spacer()
                        Button("Limpar") { textInput = "" }
                            .font(.caption).foregroundStyle(.red)
                    }
                    .padding()
                    .glass()
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
    
    func TextInputView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cole o texto do seu treino:")
                .font(.caption).foregroundStyle(.gray)
            
            TextEditor(text: $textInput)
                .scrollContentBackground(.hidden)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .foregroundStyle(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .padding()
    }
    
    // Botão da Aba
    func TabButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                    Text(title)
                }
                .font(.caption).bold()
                .foregroundStyle(isSelected ? Color.white : Color.gray)
                
                Rectangle()
                    .fill(isSelected ? Color.neonGreen : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
    
    // Badge de Formato
    func FormatBadge(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
}
