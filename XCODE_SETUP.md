# ⚙️ CONFIGURAÇÕES RECOMENDADAS DO XCODE PARA PRODUÇÃO

## 🎯 Build Settings

### Deployment Info
```
iOS Deployment Target: 17.0 (ou mínimo que você suporte)
Devices: iPhone (ou Universal se quiser iPad)
```

### Signing & Capabilities
```
Automatically manage signing: ✓
Team: Seu time de desenvolvimento
Bundle Identifier: com.seudominio.maratonanopulso
```

**Capabilities necessárias:**
- ☑️ HealthKit
- ☑️ Background Modes → Audio
- ☑️ App Groups (se compartilhar dados com Watch)

### Build Settings
```
SWIFT_OPTIMIZATION_LEVEL (Release): -O -whole-module-optimization
SWIFT_COMPILATION_MODE: whole module
ENABLE_BITCODE: NO
DEBUG_INFORMATION_FORMAT (Release): DWARF with dSYM File
```

### Preprocessor Macros
```
DEBUG: Apenas em Debug configuration
```

---

## 📦 Configuração de Schemes

### Run Scheme
```
Build Configuration: Debug
Diagnostic Options:
  - Thread Sanitizer: OFF (causa lentidão)
  - Address Sanitizer: OFF (apenas para debugging específico)
  - Main Thread Checker: ON
  - Malloc Stack Logging: OFF
```

### Archive Scheme
```
Build Configuration: Release
Skip Install: NO
Reveal Archive in Organizer: YES
```

---

## 🧪 Testes Recomendados

### Antes de cada Archive:
1. **Product → Clean Build Folder** (Cmd+Shift+K)
2. **Teste em dispositivo físico** (não simulador)
3. **Profile com Instruments:**
   - Time Profiler (performance)
   - Leaks (memory leaks)
   - Network (tráfego OpenAI)

### Comandos úteis:
```bash
# Limpar todos os builds
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Verificar assinaturas
codesign -dv --verbose=4 YourApp.app

# Testar notificações push (se usar)
xcrun simctl push booted com.yourapp.bundle payload.json
```

---

## 📱 Info.plist - Configurações Essenciais

### Privacy - Descrições (OBRIGATÓRIO)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Permite comandos de voz para criar treinos personalizados com IA</string>

<key>NSHealthShareUsageDescription</key>
<string>Acessa seu histórico de corridas para treinos inteligentes baseados no seu desempenho real</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Salva os treinos gerados pela IA Coach diretamente no Apple Health</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Converte seus comandos de voz em instruções de treino</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Rastreia sua corrida com GPS para dados precisos de distância e ritmo</string>
<!-- Apenas se usar localização -->
```

### Background Modes (Se necessário)
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <!-- Apenas se permitir gravação em background -->
</array>
```

### Outros
```xml
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>

<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <!-- Adicione outros se suportar landscape -->
</array>

<key>CFBundleDisplayName</key>
<string>Maratona no Pulso</string>

<key>CFBundleShortVersionString</key>
<string>1.0</string>

<key>CFBundleVersion</key>
<string>1</string>
<!-- Incremente a cada build enviado ao TestFlight -->
```

---

## 🔐 Segurança Adicional

### Validações de Runtime
Adicione ao início do app:

```swift
#if DEBUG
print("⚠️ RUNNING IN DEBUG MODE")
#else
// Validações de produção
assert(!Secrets.openAIAPIKey.isEmpty, "API Key não configurada")
assert(!Secrets.openAIAPIKey.contains("YOUR_KEY"), "API Key placeholder detectada")
#endif
```

### Obfuscação (Opcional)
Se quiser esconder strings sensíveis:
```swift
// Em vez de:
let url = "https://api.openai.com/v1/chat/completions"

// Use:
let parts = ["https://", "api.", "openai.", "com", "/v1/chat/completions"]
let url = parts.joined()
```

---

## 📊 Analytics Setup (Recomendado)

### Firebase (Gratuito e completo)
1. Adicione Firebase SDK via SPM:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
2. Importe: FirebaseAnalytics, FirebaseCrashlytics
3. Configure no AppDelegate ou @main:
   ```swift
   import FirebaseCore
   
   @main
   struct YourApp: App {
       init() {
           FirebaseApp.configure()
       }
   }
   ```

### Eventos Críticos para Rastrear:
```swift
// Login/Onboarding
Analytics.logEvent("onboarding_completed", parameters: nil)

// Uso de Features
Analytics.logEvent("voice_command_used", parameters: ["duration": duration])
Analytics.logEvent("workout_generated", parameters: ["num_days": count])
Analytics.logEvent("workout_saved", parameters: nil)

// Erros
Analytics.logEvent("api_error", parameters: ["code": errorCode])
```

---

## 🚀 Script de Build Automation (Opcional)

Crie `prebuild.sh`:
```bash
#!/bin/bash

echo "🔍 Verificando configurações..."

# Verifica se Secrets.swift existe
if [ ! -f "Secrets.swift" ]; then
    echo "❌ ERRO: Secrets.swift não encontrado!"
    exit 1
fi

# Verifica se API key não é placeholder
if grep -q "SUA_NOVA_CHAVE_AQUI" Secrets.swift; then
    echo "❌ ERRO: API Key não configurada!"
    exit 1
fi

# Verifica Info.plist tem descrições
if ! grep -q "NSMicrophoneUsageDescription" Info.plist; then
    echo "⚠️ AVISO: Falta descrição de Microfone no Info.plist"
fi

echo "✅ Verificações OK"
```

Adicione ao Build Phases:
```
New Run Script Phase:
bash "${PROJECT_DIR}/prebuild.sh"
```

---

## 📝 Notas Finais

### Versioning
- **Semantic Versioning**: MAJOR.MINOR.PATCH (ex: 1.0.0)
- Incremente PATCH para bugfixes
- Incremente MINOR para novas features
- Incremente MAJOR para breaking changes

### Release Notes Template
```
Versão 1.0.0
- 🎉 Lançamento inicial
- 🧠 Coach AI com comandos de voz
- 📊 Integração com Apple Health
- ⌚ Sincronização com Apple Watch

Bugfixes:
- Corrigido crash ao gerar planos longos
- Melhorada performance de transcrição

Conhecido:
- Notificações no Watch podem demorar alguns segundos
```

---

## 🔍 Troubleshooting

### "App crashes ao iniciar"
→ Verifique permissões no Info.plist

### "API Key inválida"
→ Confirme que não há espaços em branco: `.trimmingCharacters(in: .whitespacesAndNewlines)`

### "HealthKit não sincroniza"
→ Capabilities → HealthKit deve estar ✓
→ Rode em dispositivo físico (simulador não suporta HealthKit completo)

### "Audio warnings persistem"
→ Verifique se bufferSize é 4096
→ Teste com IOBufferDuration = 0.02

---

**Última atualização:** 02/12/2024
