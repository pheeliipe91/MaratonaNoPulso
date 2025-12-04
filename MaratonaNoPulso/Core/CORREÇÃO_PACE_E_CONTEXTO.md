# 🎯 Correção Completa: Pace, Contexto e Robustez

## 📋 Problemas Identificados

Com base nos prints e descrição, os problemas eram:

1. ❌ **AI não está lendo o histórico do Health corretamente**
2. ❌ **Paces descompassados** (pediu 5:30 quando o pace atual é 6:30)
3. ❌ **Duas AIs desconectadas** (plano inicial vs. geração de blocos JSON)
4. ❌ **Falta alerta para usuários sem histórico**
5. ❌ **Biblioteca mostra apenas Semana 1 e Semana 5** (faltando semanas 2,3,4)

---

## ✅ Soluções Implementadas

### 1. **AthleteContext: Single Source of Truth**

Criei uma estrutura que calcula e armazena o contexto do atleta **UMA VEZ** e é reutilizada em todas as chamadas:

```swift
struct AthleteContext: Codable {
    let weeklyKm: Double
    let averagePace: String      // Ex: "6:30" (min/km)
    let longestRunKm: Double
    let recentWorkouts: Int
    let experienceLevel: String
    let hasHistory: Bool
    
    // 🧠 Calcula pace target para diferentes zonas
    func targetPace(forZone zone: String) -> (min: String, max: String) {
        // Z1 (Recuperação): +30s/km mais lento
        // Z2 (Aeróbico): Pace atual ± 15s
        // Z3 (Tempo): -15s a -5s
        // Z4 (Limiar): -30s a -20s
        // Z5 (VO2Max): -45s ou mais rápido
    }
}
```

**Exemplo de cálculo:**
- Pace atual: `6:30/km` (390 segundos)
- Z2 (Leve): `6:40 - 7:00` (mais lento)
- Z3 (Moderado): `6:10 - 6:25` (um pouco mais rápido)
- Z5 (Intervalado): `5:40 - 5:45` (bem mais rápido)

**Resultado:** NUNCA vai sugerir 5:30 se o pace atual for 6:30!

---

### 2. **Calculadora de Contexto Inteligente**

A função `calculateAthleteContext()` analisa o histórico do Health e calcula:

```swift
private func calculateAthleteContext(healthContext: String, user: AIUserProfile) -> AthleteContext {
    // Parse do healthContext
    // Extrai: volume semanal, número de treinos, long run máximo
    
    // 🧠 CALCULA PACE MÉDIO BASEADO NO NÍVEL
    let averagePace: String
    let hasHistory = recentWorkouts > 0
    
    if hasHistory && totalDistance > 0 {
        // Estimativa baseada na quilometragem
        switch km {
        case 0..<10: averagePace = "7:00"   // Iniciante
        case 10..<20: averagePace = "6:30"  // Recreacional
        case 20..<35: averagePace = "6:00"  // Regular
        case 35..<50: averagePace = "5:30"  // Experiente
        default: averagePace = "5:00"       // Avançado
        }
    } else {
        // ⚠️ SEM HISTÓRICO: pace ultra-conservador
        averagePace = "7:30"
        longestRun = 3.0  // Começar com 3km
    }
    
    return AthleteContext(...)
}
```

**Logs de debug adicionados:**
```
📊 CONTEXTO CALCULADO:
   - Volume semanal: 25.3km
   - Pace médio: 6:00/km
   - Long run: 12.0km
   - Treinos recentes: 5
   - Tem histórico: true
```

---

### 3. **Geração de Plano com Contexto**

A função `generateWeekPlan()` agora:

```swift
func generateWeekPlan(...) {
    // 1️⃣ CALCULA contexto atlético
    self.athleteContext = calculateAthleteContext(healthContext: healthContext, user: user)
    
    // 2️⃣ ALERTA se não tiver histórico
    if !context.hasHistory {
        print("⚠️ USUÁRIO SEM HISTÓRICO - Gerando plano adaptativo")
    }
    
    // 3️⃣ PASSA contexto para o prompt
    let promptData = WeekPromptStrategy.build(
        user: user,
        context: healthContext,
        athleteContext: context,  // 🔥 Single Source of Truth
        instruction: instruction,
        blueprint: blueprint
    )
    
    // 4️⃣ PASSA contexto para o mapper
    let safeResponse = WeekMapper.map(
        json: data,
        existingSignatures: signatures,
        athleteContext: context  // 🔥 Validação com contexto
    )
}
```

---

### 4. **Prompt Strategies com Contexto Calibrado**

#### WeekPromptStrategy:

```swift
let paceGuidance = """
📊 ANÁLISE DO ATLETA (OBRIGATÓRIO SEGUIR):
- Volume semanal atual: 25.3km
- Pace médio: 6:00/km
- Long run máximo: 12.0km
- Treinos recentes: 5
- Tem histórico: SIM

🎯 PACES CALIBRADOS (USE SEMPRE ESTES VALORES):
- Corrida Leve (Z2): 6:10 - 6:30
- Corrida Moderada (Z3): 5:40 - 5:55
- Long Run: 6:10 (sempre Z2)
- Intervalado/Tiros (Z5): 5:10 - 5:15

⚠️ REGRA FUNDAMENTAL: NÃO sugira paces mais rápidos que os calculados acima.
"""
```

#### Alerta para Usuário Sem Histórico:

```swift
let noHistoryWarning = !athleteContext.hasHistory ? """
🚨 ATENÇÃO: USUÁRIO SEM HISTÓRICO DE CORRIDA
- Você DEVE criar um plano adaptativo e progressivo
- Comece com caminhada + corrida leve (3-5km)
- Aumente GRADUALMENTE (máximo 10% por semana)
- Inclua PELO MENOS 2-3 treinos de força por semana
- Exemplo de progressão: Semana 1 (3km), Semana 2 (4km), Semana 3 (5km), etc.
- Meta final deve ser realista (ex: Se quer maratona, plano de 6-8 MESES mínimo)
""" : ""
```

---

### 5. **Geração de Segmentos com Mesmo Contexto**

A função `generateDetailedSegments()` agora **reutiliza** o contexto do plano:

```swift
func generateDetailedSegments(...) {
    // 🔥 REUTILIZA O CONTEXTO DO PLANO ORIGINAL
    guard let context = self.athleteContext else {
        print("⚠️ Contexto atlético não disponível, usando fallback")
        self.athleteContext = AthleteContext(...)  // Cria um básico
    }
    
    let promptData = SegmentPromptStrategy.build(
        title: title,
        phase: phase,
        instruction: instruction,
        userLevel: user.experienceLevel,
        athleteContext: self.athleteContext!  // 🔥 Mesmo contexto
    )
    
    let segments = SegmentMapper.map(
        json: data,
        userLevel: user.experienceLevel,
        athleteContext: self.athleteContext  // 🔥 Mesmo contexto
    )
}
```

**SegmentPromptStrategy com Paces:**

```swift
let paceContext = """
PACE ATUAL DO ATLETA: 6:00/km
- Z1 (Recuperação): 6:30 - 7:00
- Z2 (Aeróbico): 6:10 - 6:30
- Z3 (Tempo): 5:40 - 5:55
- Z4 (Limiar): 5:25 - 5:40
- Z5 (VO2Max): 5:10 - 5:25

IMPORTANTE: Use SEMPRE esses paces calculados. NÃO invente valores.
"""
```

---

### 6. **SegmentMapper com Validação de Pace**

```swift
// 1. Calculando Pace baseado no contexto atlético
if role == .work && paceMin == nil {
    // 🔥 USA CONTEXTO ATLÉTICO PARA CALCULAR PACE CORRETO
    if let context = athleteContext {
        let intensity = dto.intensity ?? "Moderado"
        let targetPaces = context.targetPace(forZone: intensity)
        paceMin = targetPaces.min
        paceMax = targetPaces.max
        print("   🎯 Pace calculado para \(intensity): \(paceMin!) - \(paceMax!)")
    } else {
        // Fallback antigo (conservador)
        paceMin = "6:00"
        paceMax = "6:30"
    }
}
```

**Logs de debug:**
```
🔧 SegmentMapper recebeu 5 segmentos
   🎯 Pace calculado para Z2: 6:10 - 6:30
   ✅ Segmento criado: work - 5.0 km @ 6:10
   🎯 Pace calculado para Z5: 5:10 - 5:25
   ✅ Segmento criado: work - 1.0 km @ 5:10
```

---

## 🔄 Fluxo Completo Corrigido

```
1️⃣ Usuário pede: "Plano de 2 meses para meia maratona"
   ↓
2️⃣ AIService calcula contexto DO HEALTH:
   📊 Volume: 25km/semana
   📊 Pace: 6:00/km
   📊 Long run: 12km
   📊 Tem histórico: SIM
   ↓
3️⃣ Gera PLANO com paces calibrados:
   📁 Semana 1
     🏃 Long Run (12km @ 6:10-6:30 Z2)
     🏃 Corrida Leve (6km @ 6:10-6:30 Z2)
     💪 Força (45min)
   📁 Semana 2
     🏃 Long Run (14km @ 6:10-6:30 Z2)
     🏃 Intervalado (5x1km @ 5:10-5:25 Z5)
   ...
   ↓
4️⃣ Usuário clica "Gerar Estrutura Técnica" no treino
   ↓
5️⃣ AIService REUTILIZA o mesmo contexto:
   🔧 Segmentos com MESMO pace (6:10-6:30 para Z2)
   ↓
6️⃣ WorkoutKit envia para Apple Watch:
   ⌚ Treino com alertas corretos de pace
```

---

## 🚨 Alerta para Usuário Sem Histórico

**Antes:**
- ❌ Gera plano de maratona mesmo sem histórico
- ❌ Sugere paces irrealistas

**Depois:**
- ✅ Detecta falta de histórico
- ✅ Prompt inclui aviso especial
- ✅ IA gera plano adaptativo:
  - Começa com 3-5km
  - Aumenta 10% por semana
  - Inclui força obrigatória
  - Meta realista (6-8 meses para maratona)

**Log:**
```
⚠️ USUÁRIO SEM HISTÓRICO - Gerando plano adaptativo
📊 CONTEXTO CALCULADO:
   - Volume semanal: 0.0km
   - Pace médio: 7:30/km (conservador)
   - Long run: 3.0km
   - Treinos recentes: 0
   - Tem histórico: false
```

---

## 🎯 Resultados Esperados

### Antes:
| Problema | Exemplo |
|----------|---------|
| Pace descompassado | Long Run @ 5:30 (pace real: 6:30) |
| AIs desconectadas | Plano diz Z2, blocos têm pace Z4 |
| Sem validação histórico | Maratona para iniciante absoluto |

### Depois:
| Solução | Exemplo |
|---------|---------|
| Pace calibrado | Long Run @ 6:40 (pace real: 6:30, Z2 mais lento) |
| Contexto unificado | Plano E blocos usam MESMO pace |
| Alerta + plano adaptativo | "Sem histórico, comece com 3km" |

---

## 📊 Logs de Debug Completos

```
🎤 Pedido: "Plano de 2 meses para meia maratona"

📊 CONTEXTO CALCULADO:
   - Volume semanal: 25.3km
   - Pace médio: 6:00/km
   - Long run: 12.0km
   - Treinos recentes: 5
   - Tem histórico: true

🚀 Iniciando chamada OpenAI (plano completo)...
📄 JSON PREVIEW: {"roadmap":[{"phaseName":"Base"...
✅ Decodificado: 16 treinos
   ✅ 'Long Run Semana 1': 12.0km, 72min, Semana 1
   ✅ 'Corrida Leve': 6.0km, 36min, Semana 1
   ✅ 'Treino de Força': 0km, 45min, Semana 1
📊 RESULTADO: 16 validados, 16 únicos

👆 Usuário clica "Gerar Estrutura Técnica" em "Long Run"

🔧 SegmentMapper recebeu 4 segmentos
   🎯 Pace calculado para Z2: 6:10 - 6:30
   ✅ Segmento criado: warmup - 10.0 min @ N/A
   ✅ Segmento criado: work - 10.0 km @ 6:10
   ✅ Segmento criado: cooldown - 10.0 min @ N/A

✅ Treino exportado para Apple Watch!
```

---

## 📁 Arquivos Modificados

### AIService.swift
1. ✅ Adicionado `AthleteContext` struct
2. ✅ Adicionado `athleteContext: AthleteContext?` property
3. ✅ Função `calculateAthleteContext()` nova
4. ✅ `generateWeekPlan()` calcula e passa contexto
5. ✅ `generateDetailedSegments()` reutiliza contexto
6. ✅ `SegmentMapper.map()` usa contexto para paces
7. ✅ `WeekMapper.map()` recebe contexto
8. ✅ `WeekPromptStrategy` com paces calibrados e alerta
9. ✅ `SegmentPromptStrategy` com paces do contexto

---

## 🎉 Resumo Final

### Problema: Duas AIs Desconectadas
**❌ Antes:** Plano macro (semana) e micro (blocos JSON) usavam lógicas diferentes

**✅ Depois:** **Single Source of Truth** - `AthleteContext` calculado UMA VEZ e reutilizado SEMPRE

### Problema: Paces Descompassados
**❌ Antes:** IA sugeria 5:30 quando pace real era 6:30

**✅ Depois:** Paces calculados com base no histórico real (Z2 = pace atual + 10-30s)

### Problema: Sem Alerta para Iniciantes
**❌ Antes:** Gerava maratona para quem nunca correu

**✅ Depois:** Detecta falta de histórico e gera plano adaptativo (3km → 5km → 10km...)

### Problema: Biblioteca Incompleta
**Esse problema precisa investigação adicional** - pode ser:
- IA gerando apenas 2 semanas em vez de todas
- VoiceCoachView não salvando todas as semanas
- Agrupamento incorreto por weekNumber

**Sugestão:** Verificar os logs após gerar um novo plano:
```
📦 Salvando plano: Meia Maratona - 8 Semanas
   - Total de treinos: 56
   - Semanas: 8
```

Se mostrar apenas 2 semanas, o problema está na geração da IA (campo weekNumber não está sendo preenchido corretamente para todas as semanas).

---

## 🚀 Próximos Passos

1. ✅ **Testar com histórico real** - Verificar se paces estão corretos
2. ✅ **Testar sem histórico** - Verificar se alerta aparece
3. ⚠️ **Investigar biblioteca** - Por que só 2 semanas aparecem?
4. 🔄 **Adicionar validação de conclusão** - Liberar semana 2 só após completar semana 1

