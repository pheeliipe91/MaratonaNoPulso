# ✅ CHECKLIST PRÉ-PRODUÇÃO - Maratona no Pulso

## 🔴 CRÍTICO (Obrigatório antes do lançamento)

### Segurança
- [ ] **REVOGUE A API KEY ANTIGA DA OPENAI** (exposta no código anterior)
- [ ] Crie nova API Key no dashboard OpenAI
- [ ] Configure variáveis de ambiente para CI/CD
- [ ] Adicione Secrets.swift ao .gitignore
- [ ] Verifique se nenhum commit anterior tem a chave (use git-secrets)
- [ ] Configure rate limiting no dashboard OpenAI

### Permissões e Privacy
- [ ] Verifique Info.plist com todas as descrições de uso:
  - `NSMicrophoneUsageDescription`: "Permite comandos de voz para treinos"
  - `NSHealthShareUsageDescription`: "Sincroniza seu histórico de corridas"
  - `NSHealthUpdateUsageDescription`: "Salva treinos no Apple Health"
  - `NSSpeechRecognitionUsageDescription`: "Converte sua voz em comandos"
- [ ] Teste autorização de HealthKit em dispositivo limpo
- [ ] Teste autorização de Microfone em dispositivo limpo
- [ ] Teste Speech Recognition com locale pt-BR

### Testes de Conectividade
- [ ] Teste app SEM internet (deve mostrar erro amigável)
- [ ] Teste com internet lenta (3G)
- [ ] Teste recuperação quando internet volta
- [ ] Teste limite de requisições OpenAI (429 error)
- [ ] Teste erro 401 (API key inválida)

### Áudio
- [ ] Teste com fones Bluetooth conectados
- [ ] Teste com AirPods
- [ ] Teste durante chamada telefônica
- [ ] Teste app em background durante gravação
- [ ] Verifique se não há mais warnings HALC_ProxyIOContext

## 🟡 IMPORTANTE (Recomendado)

### Performance
- [ ] Teste com planos de 30+ dias (performance de lista)
- [ ] Teste importação de contextos grandes (>5000 chars)
- [ ] Verifique uso de memória (Instruments)
- [ ] Profile o app no Xcode (Time Profiler)
- [ ] Teste em iPhone SE (tela pequena)
- [ ] Teste em iPhone 15 Pro Max (tela grande)

### Integração Watch
- [ ] Teste envio de treino do iPhone → Watch
- [ ] Verifique se notificações chegam no Watch
- [ ] Teste agendamento no app Exercício
- [ ] Teste com Watch desconectado
- [ ] Teste sincronização após reconectar Watch

### HealthKit
- [ ] Verifique se treinos salvos aparecem no app Saúde
- [ ] Teste leitura de treinos de terceiros (Strava, Nike Run Club)
- [ ] Valide cálculo de calorias (fórmula atual: peso × dist × 1.036)
- [ ] Teste com usuário que nunca correu (0km histórico)

### UI/UX
- [ ] Teste modo escuro (Dark Mode)
- [ ] Teste acessibilidade (VoiceOver)
- [ ] Teste com texto grande (Dynamic Type)
- [ ] Verifique animações em devices mais lentos
- [ ] Teste rotação de tela (se suportado)

## 🟢 BOAS PRÁTICAS (Melhorias Futuras)

### Monitoramento
- [ ] Integre sistema de crash reporting (Firebase Crashlytics)
- [ ] Configure analytics (eventos principais)
- [ ] Implemente remote config para features flags
- [ ] Adicione feedback do usuário (avaliação no App Store)

### Backend/API
- [ ] Considere criar proxy backend para OpenAI (esconde API key)
- [ ] Implemente cache local de planos gerados
- [ ] Adicione offline mode (salvar rascunhos)
- [ ] Configure backup na iCloud (opcional)

### Localização
- [ ] Adicione strings em inglês (internacionalização)
- [ ] Teste Speech Recognition em outros idiomas
- [ ] Adapte unidades (milhas vs km) conforme região

### Compliance
- [ ] Revise termos de uso da OpenAI (uso em produção)
- [ ] Adicione Política de Privacidade ao app
- [ ] Adicione Termos de Uso
- [ ] Verifique LGPD/GDPR se for distribuir na Europa
- [ ] Prepare descrição do App Store (mencione uso de IA)

## 🔧 TESTES AUTOMATIZADOS (Futuro)

### Unit Tests
- [ ] Teste parsers de JSON (SegmentMapper, WeekMapper)
- [ ] Teste lógica de duplicação (WorkoutSignature)
- [ ] Teste cálculo de pace e zonas cardíacas
- [ ] Teste validação de inputs

### UI Tests
- [ ] Teste fluxo completo: voz → plano → salvar
- [ ] Teste navegação entre tabs
- [ ] Teste import de contexto
- [ ] Teste profile settings

## 📱 TESTE EM DISPOSITIVOS REAIS

### Obrigatório
- [ ] iPhone com iOS 17+ (ou mínima suportada)
- [ ] Apple Watch (se tiver integração)
- [ ] Teste em dispositivo sem SIM (só Wi-Fi)

### Opcional mas Recomendado
- [ ] iPad (se for universal)
- [ ] Dispositivos mais antigos (A12 chip ou anterior)

## 🚀 PRÉ-LANÇAMENTO

### App Store
- [ ] Screenshots de todas as telas (6.7", 6.5", 5.5")
- [ ] Vídeo de preview (opcional mas recomendado)
- [ ] Ícone do app (1024×1024)
- [ ] Descrição completa (keywords: IA, corrida, treino, coach)
- [ ] Categoria: Saúde e Fitness
- [ ] Classificação etária
- [ ] Configure in-app purchases (se houver)

### TestFlight
- [ ] Beta test com 10-20 usuários
- [ ] Colete feedback sobre bugs
- [ ] Teste com perfis diversos (iniciante/avançado)

### Documentação
- [ ] README.md com instruções de setup
- [ ] Documente arquitetura do código
- [ ] Adicione comentários em código complexo
- [ ] Crie guia de contribuição (se for open source)

---

## 📞 SUPORTE PÓS-LANÇAMENTO

### Monitoramento
- [ ] Configure alertas para crashes (>1% crash rate)
- [ ] Monitore tempo de resposta da OpenAI
- [ ] Acompanhe reviews no App Store
- [ ] Prepare FAQ para dúvidas comuns

### Atualizações
- [ ] Planeje releases mensais
- [ ] Mantenha changelog visível
- [ ] Teste atualizações antes de submeter

---

## ⚠️ CONHECIDO E ACEITÁVEL (Não bloqueiam launch)

- Warning IOSurfaceClientSetSurfaceNotify: Comum em iOS, pode ser ignorado
- Logs de debug em modo Development: Removidos automaticamente em Release

---

**Data última revisão:** 02/12/2024
**Versão:** 1.0
**Status:** 🟡 Pendente validações críticas
