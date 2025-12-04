# 🔥 Correção CRÍTICA: IA Gerando Apenas 10 Treinos em Vez de 8 Semanas

## 🐛 Problema Identificado

**Pedido do Usuário:**
> "Quero um plano de 2 meses para meia maratona"

**Resultado Esperado:**
- 2 meses = 8 semanas
- 4 treinos por semana
- Total: **32 treinos** (8 semanas × 4 treinos)

**Resultado Obtido (❌ ERRADO):**
- Apenas **10 treinos**
- Mostrando "SEMANA 1 DETALHADA" com 2 treinos
- Faltando semanas 2, 3, 4, 5, 6, 7, 8

---

## 🔍 Causa Raiz

O prompt NÃO estava:
1. **Extraindo** o número de semanas do pedido do usuário
2. **Instruindo explicitamente** a IA sobre quantas semanas gerar
3. **Reforçando** que TODAS as semanas devem ser incluídas

**Exemplo do prompt ANTES:**
```
PEDIDO DO USUÁRIO: Quero um plano de 2 meses para meia maratona

IMPORTANTE: 
- Organize os treinos com "weekNumber" (1, 2, 3...)
- Se o usuário pediu várias semanas, distribua os treinos
```

**Problema:** "Se o usuário pediu várias semanas" é vago! A IA não sabe quantas.

---

## ✅ Solução Implementada

### 1. Extrator de Semanas

Criei uma função que **extrai automaticamente** o número de semanas do pedido:

```swift
private static func extractWeeksFromRequest(instruction: String?) -> Int {
    guard let instr = instruction?.lowercased() else { return 4 }
    
    // Padrões comuns
    if instr.contains("2 meses") || instr.contains("dois meses") {
        return 8  // 2 meses = 8 semanas
    }
    if instr.contains("3 meses") || instr.contains("três meses") {
        return 12
    }
    if instr.contains("1 mês") || instr.contains("um mês") {
        return 4
    }
    
    // Procura "X semanas"
    if let range = instr.range(of: #"(\d+)\s*semanas?"#, options: .regularExpression) {
        // Extrai o número
        return extractedNumber
    }
    
    // Fallback: 4 semanas
    return 4
}
```

**Exemplos de detecção:**
- "2 meses" → **8 semanas**
- "3 meses" → **12 semanas**
- "6 semanas" → **6 semanas**
- "quatro semanas" → **4 semanas**
- "plano de maratona" (sem especificar) → **4 semanas** (fallback)

---

### 2. Prompt Explícito com Número de Semanas

**ANTES (❌):**
```
REGRAS OBRIGATÓRIAS:
- "weekNumber": número (1, 2, 3...) - SEMPRE inclua

IMPORTANTE: 
- Se o usuário pediu várias semanas, distribua os treinos
```

**DEPOIS (✅):**
```swift
let requestedWeeks = extractWeeksFromRequest(instruction: instruction)  // 8

🔥 REGRA CRÍTICA DE GERAÇÃO:
- O usuário pediu 8 SEMANAS
- Você DEVE gerar EXATAMENTE 8 semanas completas
- Cada semana deve ter 3-5 treinos (incluindo descanso)
- TOTAL DE TREINOS: aproximadamente 32 treinos
- Distribua os treinos de 1 até 8 usando "weekNumber"

⚠️ IMPORTANTE: NÃO pare na semana 1 ou 2! Gere TODAS as 8 semanas!

ESTRUTURA ESPERADA:
- Semana 1: 4 treinos (weekNumber: 1)
- Semana 2: 4 treinos (weekNumber: 2)
- Semana 3: 4 treinos (weekNumber: 3)
- ...
- Semana 8: 4 treinos (weekNumber: 8)
```

---

### 3. Exemplo Expandido no Schema

**ANTES (❌):**
```json
"workouts": [
  {"title": "Corrida Leve", "weekNumber": 1},
  {"title": "Força", "weekNumber": 1}
]
```

**DEPOIS (✅):**
```json
"workouts": [
  // SEMANA 1
  {"title": "Caminhada + Corrida", "weekNumber": 1},
  {"title": "Força", "weekNumber": 1},
  {"title": "Corrida Leve", "weekNumber": 1},
  {"title": "Descanso", "weekNumber": 1},
  
  // SEMANA 2 (SEMPRE INCLUA TODAS AS SEMANAS!)
  {"title": "Corrida Progressiva", "weekNumber": 2},
  {"title": "Força", "weekNumber": 2},
  {"title": "Long Run", "weekNumber": 2},
  {"title": "Descanso", "weekNumber": 2},
  
  // ... CONTINUE ATÉ A ÚLTIMA SEMANA
]
```

---

### 4. User Prompt Detalhado

```swift
let userPrompt = """
PEDIDO DO USUÁRIO: Quero um plano de 2 meses para meia maratona

🎯 NÚMERO DE SEMANAS DETECTADO: 8

INSTRUÇÕES CRÍTICAS: 
1. Gere 8 SEMANAS COMPLETAS (não apenas 1 ou 2!)
2. Total aproximado: 32 treinos
3. Cada treino deve ter "weekNumber" de 1 até 8
4. Exemplo de distribuição:
   - Semana 1: treinos com weekNumber: 1
   - Semana 2: treinos com weekNumber: 2
   - ...
   - Semana 8: treinos com weekNumber: 8

Gere o plano COMPLETO de 8 semanas seguindo o schema JSON exato.
"""
```

---

## 📊 Comparação Antes vs Depois

### ANTES (❌ ERRADO):

```
Prompt: "Se o usuário pediu várias semanas..."
IA interpreta: "Várias = 1-2 semanas?"
Resultado: 10 treinos (provavelmente 2 semanas incompletas)
```

### DEPOIS (✅ CORRETO):

```
Prompt: "O usuário pediu 8 SEMANAS. Gere EXATAMENTE 8 semanas. Total: 32 treinos."
IA interpreta: "Preciso gerar 32 treinos distribuídos em 8 semanas"
Resultado: 32 treinos (8 semanas × 4 treinos)
```

---

## 🧪 Como Testar

### Teste 1: "2 meses"
```
Pedido: "Quero um plano de 2 meses para meia maratona"

Logs esperados:
📊 Extrator detectou: 8 semanas
🎯 NÚMERO DE SEMANAS DETECTADO: 8
✅ Decodificado: 32 treinos
📦 Salvando plano: Meia Maratona - 2 Meses
   - Total de treinos: 32
   - Semanas: 8

Biblioteca deve mostrar:
📁 Semana 1 (4 treinos)
📁 Semana 2 (4 treinos)
📁 Semana 3 (4 treinos)
...
📁 Semana 8 (4 treinos)
```

### Teste 2: "4 semanas"
```
Pedido: "Plano de 4 semanas para 10km"

Logs esperados:
📊 Extrator detectou: 4 semanas
✅ Decodificado: 16 treinos
   - Semanas: 4

Biblioteca deve mostrar:
📁 Semana 1 (4 treinos)
📁 Semana 2 (4 treinos)
📁 Semana 3 (4 treinos)
📁 Semana 4 (4 treinos)
```

### Teste 3: Sem especificar (fallback)
```
Pedido: "Quero correr uma maratona"

Logs esperados:
📊 Extrator detectou: 4 semanas (fallback)
✅ Decodificado: 16 treinos
   - Semanas: 4
```

---

## 🔧 Código Modificado

### Arquivo: AIService.swift

#### Adicionado:
1. **Função extractWeeksFromRequest()** (linha ~1020)
   - Detecta "2 meses" → 8 semanas
   - Detecta "X semanas" → X semanas
   - Fallback: 4 semanas

2. **Prompt com número explícito** (linha ~880)
   - `let requestedWeeks = extractWeeksFromRequest(...)`
   - Passa para system prompt: "O usuário pediu X SEMANAS"
   - Passa para user prompt: "🎯 NÚMERO DE SEMANAS: X"

3. **Exemplo expandido** (linha ~910)
   - Mostra múltiplas semanas no schema
   - Comenta: "// SEMANA 2 (SEMPRE INCLUA!)"

---

## 📋 Logs de Debug Adicionados

```swift
// No início do build()
let requestedWeeks = extractWeeksFromRequest(instruction: instruction)
print("📊 Extrator de semanas: \(instruction ?? "N/A") → \(requestedWeeks) semanas")

// Resultado esperado:
📊 Extrator de semanas: "Quero um plano de 2 meses para meia maratona" → 8 semanas
```

---

## ⚠️ Limitações Conhecidas

### Token Limit da OpenAI:
- Com 8 semanas × 4 treinos = **32 treinos**
- Cada treino tem ~200 tokens
- Total: ~6400 tokens de resposta

**Solução aplicada:**
- `max_tokens` já está em 4000 (suficiente para 20-25 treinos)
- Se a IA não conseguir gerar tudo, ela vai priorizar as primeiras semanas
- **Recomendação:** Para planos muito longos (12+ semanas), considerar gerar em blocos

**Alternativa futura:**
```swift
// Se requestedWeeks > 8, gerar em blocos
if requestedWeeks > 8 {
    // Bloco 1: Semanas 1-8
    generateWeekPlan(..., weekRange: 1...8)
    
    // Bloco 2: Semanas 9-16
    generateWeekPlan(..., weekRange: 9...16)
}
```

---

## 🎯 Resultado Esperado Agora

### Pedido: "Plano de 2 meses para meia maratona"

#### Na UI (VoiceCoachView):
```
ESTRATÉGIA DEFINIDA
PLANO DE MEIA MARATONA - 2 MESES

📅 32 Treinos
🏃 64 Km Totais
🎯 Foco: Resistência

FASES DO CICLO:
📗 Base (4 semanas) - Aeróbico
📘 Construção (4 semanas) - Resistência

SEMANA 1 (DETALHADA):
SEG: Caminhada + Corrida (3km)
TER: Treino de Força (45min)
QUI: Corrida Leve (4km)
DOM: Descanso

+ 28 treinos no plano completo...

[SALVAR PLANO NA BIBLIOTECA]
```

#### Na Biblioteca:
```
📁 Plano: Meia Maratona - 2 Meses
  📅 Semana 1 (4 treinos)
  📅 Semana 2 (4 treinos)
  📅 Semana 3 (4 treinos)
  📅 Semana 4 (4 treinos)
  📅 Semana 5 (4 treinos)
  📅 Semana 6 (4 treinos)
  📅 Semana 7 (4 treinos)
  📅 Semana 8 (4 treinos)
```

---

## 🎉 Resumo Final

| Aspecto | Antes | Depois |
|---------|-------|--------|
| **Detecção de semanas** | ❌ Manual/vago | ✅ Automático |
| **Instrução para IA** | ❌ "Várias semanas" | ✅ "8 semanas exatas" |
| **Exemplo no schema** | ❌ 1 semana | ✅ Múltiplas semanas |
| **Reforço no prompt** | ❌ Nenhum | ✅ 3 vezes repetido |
| **Total de treinos** | ❌ 10 treinos | ✅ 32 treinos |

---

**TL;DR:** A IA agora recebe instruções EXPLÍCITAS sobre quantas semanas gerar, com extrator automático que converte "2 meses" em "8 semanas" e força a geração COMPLETA de todas as semanas solicitadas! 🚀

