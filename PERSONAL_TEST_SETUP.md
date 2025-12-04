# 🧪 CONFIGURAÇÃO PARA TESTE PESSOAL

## ⚠️ IMPORTANTE
Este setup é para **TESTE PESSOAL APENAS**. Não distribua este build.

---

## ✅ CHECKLIST SIMPLIFICADO (Teste Pessoal)

### Obrigatório Antes de Instalar
- [ ] Info.plist configurado (permissões de Microfone e HealthKit)
- [ ] Capabilities habilitadas no Xcode (HealthKit, Audio)
- [ ] Secrets.swift com API key válida
- [ ] Build em modo Release (não Debug)
- [ ] Instalado via Xcode ou TestFlight pessoal

### Testes Essenciais
- [ ] Gravação de áudio funciona
- [ ] Comandos de voz geram planos
- [ ] Sincronização com Apple Health
- [ ] Watch recebe treinos (se tiver Apple Watch)

### Opcional mas Recomendado
- [ ] Teste com iPhone em modo Avião (ver como app se comporta)
- [ ] Teste gerando plano de 30 dias (performance)
- [ ] Verifique uso de bateria (Settings → Battery)

---

## 📝 CONFIGURAÇÃO DO INFO.PLIST

Cole estas linhas no seu Info.plist (botão direito → Open As → Source Code):

```xml
<!-- ADICIONE ESTAS LINHAS -->
<key>NSMicrophoneUsageDescription</key>
<string>Permite comandos de voz para criar treinos personalizados com IA</string>

<key>NSHealthShareUsageDescription</key>
<string>Acessa seu histórico de corridas para treinos inteligentes</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Salva treinos gerados pela IA no Apple Health</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Converte comandos de voz em instruções de treino</string>
```

---

## 🚀 INSTALAÇÃO NO SEU IPHONE

### Opção 1: Via Xcode (Mais Rápido)
1. Conecte seu iPhone via cabo
2. Selecione seu device no topo do Xcode
3. Product → Run (Cmd+R)
4. Aceite permissões quando solicitado

### Opção 2: Via TestFlight Pessoal (Mais Real)
1. Archive o app (Product → Archive)
2. Distribute App → TestFlight Internal Only
3. Instale o TestFlight no seu iPhone
4. Abra o link e instale o app

---

## 🔍 MONITORAMENTO DURANTE OS TESTES

### Console Logs (Enquanto conectado no Xcode)
Window → Devices and Simulators → Seu iPhone → Console

**Filtros úteis:**
- `category:audio` - Ver logs de gravação
- `category:network` - Ver chamadas OpenAI
- `error` - Ver apenas erros

### Uso de Dados
Settings → Cellular → Maratona no Pulso

**Estimativa de consumo:**
- 1 comando de voz: ~2KB
- 1 plano gerado (7 dias): ~15-30KB
- 1 plano grande (30 dias): ~50-80KB

**Custos OpenAI estimados:**
- Plano simples (7 dias): ~$0.02-0.05
- Plano complexo (30 dias): ~$0.10-0.15

### Bateria
Settings → Battery → Show Activity

Se estiver consumindo >5% por hora em uso normal, algo está errado.

---

## 🐛 PROBLEMAS COMUNS E SOLUÇÕES

### "App não instala no iPhone"
**Causa:** Certificado de desenvolvedor
**Solução:**
1. Settings → General → VPN & Device Management
2. Confie no seu perfil de desenvolvedor

### "Microfone não funciona"
**Causa:** Permissão negada ou Info.plist faltando
**Solução:**
1. Settings → Privacy → Microphone → Maratona no Pulso (ativar)
2. Se não aparecer, verifique Info.plist

### "HealthKit não sincroniza"
**Causa:** Capability não habilitada
**Solução:**
1. Xcode → Target → Signing & Capabilities
2. + Capability → HealthKit

### "API retorna erro 401"
**Causa:** API key inválida ou expirada
**Solução:**
1. Teste a chave diretamente:
```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer SUA_CHAVE_AQUI"
```
2. Se falhar, gere nova chave no dashboard OpenAI

### "Warnings de áudio continuam"
**Verificações:**
1. Confirme que AudioManager.swift tem `bufferSize: 4096`
2. Reinicie o iPhone
3. Teste em ambiente silencioso (ruído excessivo pode causar overload)

---

## 📊 TESTES SUGERIDOS PARA ESTA SEMANA

### Segunda-feira
- [ ] Instalar app no iPhone
- [ ] Teste básico: "Cria um treino de 5k"
- [ ] Verificar se aparece no Health app

### Terça-feira  
- [ ] Comando complexo: "Quero um plano de 2 semanas pra maratona"
- [ ] Testar edição de perfil
- [ ] Verificar consumo de bateria

### Quarta-feira
- [ ] Teste com Watch (se tiver)
- [ ] Enviar treino para Watch
- [ ] Verificar notificação no Watch

### Quinta-feira
- [ ] Teste offline (modo avião)
- [ ] Verificar mensagens de erro
- [ ] Testar recuperação quando volta internet

### Sexta-feira
- [ ] Teste de stress: Gerar 3 planos seguidos
- [ ] Importar contexto grande (copiar texto de 1000+ palavras)
- [ ] Testar análise pós-treino

### Sábado/Domingo
- [ ] Usar o app numa corrida real!
- [ ] Salvar treino manual no Health
- [ ] Ver se IA detecta o treino e sugere próximos passos

---

## 📈 FEEDBACK PARA SI MESMO

Mantenha notas durante a semana:

**O que funcionou bem:**
- 

**O que teve problema:**
- 

**Ideias de melhoria:**
- 

**Bugs encontrados:**
- 

---

## ⏭️ DEPOIS DOS TESTES (Antes de distribuir)

Se decidir distribuir para outras pessoas depois:
1. ✅ REVOGUE a API key atual
2. ✅ Crie nova chave
3. ✅ Adicione Secrets.swift ao .gitignore
4. ✅ Configure backend proxy (recomendado)
5. ✅ Adicione analytics (Firebase)
6. ✅ Beta test com 10+ pessoas

---

## 🆘 EMERGÊNCIA

### App travou e não abre mais
```bash
# Resetar UserDefaults
Settings → Maratona no Pulso → Reset App Data (se implementado)

# Ou reinstale via Xcode
Product → Clean Build Folder
Product → Run
```

### Conta OpenAI bloqueada
- Verifique saldo em https://platform.openai.com/usage
- Adicione créditos se necessário
- Limite mensal: $5-10 é suficiente para testes pessoais

### Dúvida técnica específica
- Revise os comentários com ✅ no código
- Consulte CORRECTIONS_REPORT.md
- Use os logs do AppLogger para debug

---

**Última atualização:** 02/12/2024
**Modo:** Teste Pessoal
**Duração:** 1 semana
