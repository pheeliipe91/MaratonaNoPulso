# 🚀 INSTALAR AGORA - Guia Rápido

## ⏱️ Tempo estimado: 10 minutos

---

## PASSO 1: Configure Info.plist (2 min)

1. No Xcode, abra o arquivo `Info.plist`
2. Botão direito → **Open As → Source Code**
3. Cole este bloco ANTES do último `</dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Permite comandos de voz para criar treinos com IA</string>
<key>NSHealthShareUsageDescription</key>
<string>Lê seu histórico de corridas para treinos personalizados</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Salva treinos gerados pela IA no Apple Health</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Converte sua voz em instruções de treino</string>
```

4. Salve (Cmd+S)

---

## PASSO 2: Configure Capabilities (1 min)

1. No Xcode, clique no **projeto** (topo da árvore de arquivos)
2. Selecione o **Target** principal
3. Aba **Signing & Capabilities**
4. Clique em **+ Capability**
5. Adicione:
   - ☑️ **HealthKit**
   - ☑️ **Background Modes** → marque **Audio**

---

## PASSO 3: Conecte seu iPhone (1 min)

1. Conecte iPhone via cabo USB
2. Desbloqueie o iPhone
3. Se aparecer "Trust This Computer?" → **Trust**
4. No Xcode, no topo, selecione seu iPhone (ao lado do botão Play)

---

## PASSO 4: Build e Instale (3 min)

1. No Xcode: **Product → Clean Build Folder** (Cmd+Shift+K)
2. **Product → Run** (Cmd+R)
3. Aguarde o build (pode demorar 1-2 minutos na primeira vez)
4. App abrirá automaticamente no iPhone

---

## PASSO 5: Aceite Permissões (1 min)

Quando o app abrir, você verá pop-ups pedindo permissão:

1. **Microfone** → Permitir
2. **Speech Recognition** → Permitir
3. **Health** → Permitir (escolha os dados que quiser compartilhar)

---

## PASSO 6: Primeiro Teste (2 min)

1. Abra a aba **Coach AI** (ícone de microfone)
2. Toque no **botão verde grande** (microfone)
3. Fale: **"Oi, cria um treino de 5 km pra mim"**
4. Toque no botão **vermelho** para parar
5. Aguarde a IA gerar o plano (~10-15 segundos)

### ✅ Se funcionou:
Você verá um card com o plano de treino gerado!

### ❌ Se deu erro:
- Verifique conexão com internet
- Confira se a API key está correta em `Secrets.swift`
- Olhe o Console do Xcode para ver o erro específico

---

## 🎉 PRONTO!

Seu app está instalado e funcionando. Agora você pode:

- Gerar planos de treino com voz
- Salvar na Biblioteca
- Sincronizar com Apple Health
- Enviar para o Apple Watch (se tiver)

---

## 🐛 RESOLUÇÃO RÁPIDA DE PROBLEMAS

### Erro: "App não instala"
```
Settings → General → VPN & Device Management
→ Confie no seu perfil de desenvolvedor
```

### Erro: "No matching provisioning profiles found"
```
Xcode → Target → Signing & Capabilities
→ Ative "Automatically manage signing"
→ Selecione seu Apple ID em "Team"
```

### Erro: "Command CodeSign failed"
```
Xcode → Preferences → Accounts
→ Adicione seu Apple ID se não estiver lá
```

### Microfone não pega áudio
```
Settings → Privacy & Security → Microphone
→ Maratona no Pulso → ON
```

### HealthKit não aparece nada
```
1. Rode o app
2. Abra o app "Health" nativo do iOS
3. Browse → Activity → Workouts
4. Verifique se há treinos salvos
```

### API retorna erro
```
1. Verifique saldo: https://platform.openai.com/usage
2. Teste a chave:
   curl https://api.openai.com/v1/models \
     -H "Authorization: Bearer SUA_CHAVE"
```

---

## 📱 ATALHOS ÚTEIS DO XCODE

| Ação | Atalho |
|------|--------|
| Build e Run | Cmd+R |
| Stop | Cmd+. |
| Clean | Cmd+Shift+K |
| Console | Cmd+Shift+Y |
| Devices | Cmd+Shift+2 |

---

## 📊 MONITORANDO DURANTE USO

### Ver Logs em Tempo Real
1. Window → Devices and Simulators
2. Selecione seu iPhone
3. Open Console
4. Digite no filtro: `process:MaratonaNoPulso`

### Ver Uso de Memória
1. Com app rodando, no Xcode:
2. Debug Navigator (Cmd+7)
3. Veja Memory, CPU, Network

---

## 🎯 PRÓXIMOS TESTES SUGERIDOS

### Teste 1: Comando Simples
**Fale:** "Cria um treino de corrida de 30 minutos"

### Teste 2: Comando Complexo
**Fale:** "Quero um plano de 2 semanas para melhorar meu ritmo nos 10k"

### Teste 3: Importar Contexto
1. Toque no ícone de 📎 (paperclip)
2. Cole: "Corri 5km em 28 minutos ontem. Quero melhorar."
3. Fale seu comando normalmente

### Teste 4: Salvar e Ver na Biblioteca
1. Após gerar plano, toque "SALVAR PLANO"
2. Vá para aba "Biblioteca"
3. Veja seu plano salvo

### Teste 5: Sincronização Health
1. Após salvar plano
2. Abra app "Health"
3. Browse → Activity → Workouts
4. Verifique se aparecem os treinos

---

## ⚠️ LIMITAÇÕES DO TESTE PESSOAL

Durante esta semana de testes:

✅ **Pode fazer:**
- Quantos comandos quiser
- Salvar quantos planos quiser
- Testar em qualquer lugar

❌ **Evite:**
- Compartilhar o build com outras pessoas
- Fazer commit do Secrets.swift no Git público
- Gerar 100+ planos por dia (custo desnecessário)

---

## 💰 CUSTOS DURANTE TESTES

**OpenAI GPT-4:**
- Input: $0.03 por 1K tokens (~750 palavras)
- Output: $0.06 por 1K tokens

**Estimativa realista:**
- 10 planos simples/dia: ~$0.50/dia = $3.50/semana
- 30 planos complexos/dia: ~$2/dia = $14/semana

**Seu saldo atual:** Verifique em https://platform.openai.com/usage

---

## 🆘 SUPORTE DURANTE TESTES

Se algo não funcionar:
1. Verifique o Console (Cmd+Shift+Y no Xcode)
2. Procure linhas com ❌ ou ERROR
3. Copie a mensagem e analise

**Erros comuns e soluções estão em:** `PERSONAL_TEST_SETUP.md`

---

**Boa sorte com os testes! 🏃‍♂️💨**
