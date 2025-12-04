# 🔍 Problema: Biblioteca Mostrando Apenas 2 Semanas

## 🐛 Diagnóstico

Nos screenshots, a biblioteca mostra:
- ✅ Semana 1 (4 treinos)
- ❌ Semanas 2, 3, 4 (FALTANDO)
- ✅ Semana 5 (4 treinos)

**Total:** 8 treinos em vez de 16+ esperados

---

## 🔎 Causa Raiz

O problema está no campo `weekNumber` que não está sendo preenchido pela IA para **todos** os treinos.

### Código de Agrupamento (VoiceCoachView.swift):

```swift
let groupedByWeek = Dictionary(grouping: workouts) { $0.weekNumber ?? 1 }
```

**O que acontece:**
- ✅ Treinos COM `weekNumber = 1` → Vão para Semana 1
- ✅ Treinos COM `weekNumber = 5` → Vão para Semana 5
- ❌ Treinos SEM `weekNumber` (nil) → **TAMBÉM vão para Semana 1** (por causa do `?? 1`)

**Resultado:** Apenas as semanas explicitamente preenchidas pela IA aparecem.

---

## ✅ Solução Implementada no AIService.swift

### 1. Prompt Melhorado

O `WeekPromptStrategy` agora **FORÇA** a IA a preencher `weekNumber`:

```swift
REGRAS OBRIGATÓRIAS:
4. Campos NUMÉRICOS são obrigatórios:
   - "weekNumber": número (1, 2, 3...) - SEMPRE inclua

IMPORTANTE: 
- Organize os treinos com "weekNumber" (1, 2, 3...)
- Se o usuário pediu várias semanas, distribua os treinos
```

### 2. Exemplo de Schema Explícito

```json
{
  "workouts": [
    {
      "title": "Long Run",
      "weekNumber": 1,  // ← EXPLÍCITO
      ...
    },
    {
      "title": "Corrida Leve",
      "weekNumber": 2,  // ← EXPLÍCITO
      ...
    }
  ]
}
```

### 3. Validação no WeekMapper

O `WeekMapper` já captura o campo corretamente:

```swift
return AIWorkoutPlan(
    title: title,
    weekNumber: dto.weekNumber,  // ✅ Capturado
    ...
)
```

---

## 🧪 Como Testar se Foi Corrigido

### Teste 1: Gerar Novo Plano

1. No app, peça: **"Quero um plano de 4 semanas para 10km"**

2. Verifique os **logs no console** durante a geração:

```
📄 JSON PREVIEW: {"workouts":[{"title":"Long Run", "weekNumber": 1...
✅ Decodificado: 16 treinos
   ✅ 'Long Run Semana 1': 10.0km, 60min, Semana 1
   ✅ 'Corrida Leve': 5.0km, 30min, Semana 1
   ✅ 'Long Run Semana 2': 11.0km, 66min, Semana 2  ← IMPORTANTE
   ✅ 'Intervalado': 6.0km, 36min, Semana 2
   ✅ 'Long Run Semana 3': 12.0km, 72min, Semana 3  ← IMPORTANTE
   ...
📊 RESULTADO: 16 validados, 16 únicos

📦 Salvando plano: Plano 10km - 4 Semanas
   - Total de treinos: 16
   - Semanas: 4  ← DEVE SER 4, NÃO 2
```

3. **Na biblioteca**, você deve ver:
   - 📁 Semana 1 (4 treinos)
   - 📁 Semana 2 (4 treinos)
   - 📁 Semana 3 (4 treinos)
   - 📁 Semana 4 (4 treinos)

---

### Teste 2: Verificar JSON da IA

Se ainda aparecerem apenas 2 semanas, adicione este código **temporário** no `WeekMapper`:

```swift
// 🔍 DEBUG: Imprimir weekNumber de cada treino
print("🔍 TREINOS RECEBIDOS:")
for (index, dto) in (wrapper.workouts ?? []).enumerated() {
    print("   [\(index)] \(dto.title ?? "Sem título") - Semana: \(dto.weekNumber ?? 999)")
}
```

**Resultado esperado:**
```
🔍 TREINOS RECEBIDOS:
   [0] Long Run - Semana: 1
   [1] Corrida Leve - Semana: 1
   [2] Força - Semana: 1
   [3] Descanso - Semana: 1
   [4] Long Run - Semana: 2
   [5] Intervalado - Semana: 2
   [6] Força - Semana: 2
   [7] Descanso - Semana: 2
   ...
```

**Se aparecer:**
```
🔍 TREINOS RECEBIDOS:
   [0] Long Run - Semana: 1
   [1] Corrida Leve - Semana: 999  ← nil convertido
   [2] Força - Semana: 999
   [3] Long Run - Semana: 5
```

**Então a IA AINDA não está preenchendo o campo corretamente.**

---

## 🔧 Solução Adicional (Se Necessário)

### Opção A: Fallback Inteligente no WeekMapper

Se a IA continuar falhando, podemos **inferir** a semana baseado na posição:

```swift
// No WeekMapper, ANTES do loop
var inferredWeek = 1
var workoutsInCurrentWeek = 0

let validWorkouts = (wrapper.workouts ?? []).compactMap { dto -> AIWorkoutPlan? in
    guard let title = dto.title else { return nil }
    
    // 🔥 INFERÊNCIA DE SEMANA
    let finalWeekNumber: Int
    if let week = dto.weekNumber {
        finalWeekNumber = week
        inferredWeek = week
        workoutsInCurrentWeek = 1
    } else {
        // Se não tem weekNumber, incrementa contador
        workoutsInCurrentWeek += 1
        
        // A cada 4 treinos (exemplo), muda de semana
        if workoutsInCurrentWeek > 4 {
            inferredWeek += 1
            workoutsInCurrentWeek = 1
        }
        
        finalWeekNumber = inferredWeek
        print("   ⚠️ '\(title)': weekNumber faltando, inferindo Semana \(finalWeekNumber)")
    }
    
    return AIWorkoutPlan(
        ...
        weekNumber: finalWeekNumber,  // ✅ Sempre preenchido
        ...
    )
}
```

### Opção B: Forçar Prompt Mais Rígido

Se a IA ignorar as instruções, podemos usar **few-shot learning**:

```swift
let exampleSchema = """
{
  "workouts": [
    {"title": "Long Run", "weekNumber": 1, ...},
    {"title": "Corrida Leve", "weekNumber": 1, ...},
    {"title": "Força", "weekNumber": 1, ...},
    {"title": "Descanso", "weekNumber": 1, ...},
    {"title": "Long Run", "weekNumber": 2, ...},  ← Mostrar explicitamente
    {"title": "Intervalado", "weekNumber": 2, ...},
    {"title": "Força", "weekNumber": 2, ...},
    {"title": "Descanso", "weekNumber": 2, ...}
  ]
}
"""

let system = """
Você DEVE seguir EXATAMENTE este padrão:
- 4 treinos por semana
- weekNumber SEMPRE preenchido
- Distribuir TODOS os treinos pelas semanas

ERRADO: [treino1: week=1, treino2: week=null, treino3: week=5]
CERTO: [treino1: week=1, treino2: week=1, treino3: week=1, treino4: week=1, treino5: week=2...]

\(exampleSchema)
"""
```

---

## 📊 Exemplo de Prompt Ideal para Usuário

Quando o usuário pede:
> "Quero um plano de 2 meses para meia maratona"

A IA deve retornar:

```json
{
  "roadmap": [
    {"phaseName": "Base", "duration": "4 semanas", "focus": "Aeróbico"},
    {"phaseName": "Construção", "duration": "4 semanas", "focus": "Resistência"}
  ],
  "workouts": [
    // SEMANA 1
    {"title": "Long Run", "weekNumber": 1, "distance": 10, "duration": 60},
    {"title": "Corrida Leve", "weekNumber": 1, "distance": 5, "duration": 30},
    {"title": "Força", "weekNumber": 1, "distance": 0, "duration": 45},
    {"title": "Descanso", "weekNumber": 1, "distance": 0, "duration": 0},
    
    // SEMANA 2
    {"title": "Long Run", "weekNumber": 2, "distance": 12, "duration": 72},
    {"title": "Intervalado", "weekNumber": 2, "distance": 6, "duration": 36},
    {"title": "Força", "weekNumber": 2, "distance": 0, "duration": 45},
    {"title": "Descanso", "weekNumber": 2, "distance": 0, "duration": 0},
    
    // SEMANA 3...
    // ...
    // SEMANA 8
    {"title": "Long Run", "weekNumber": 8, "distance": 18, "duration": 108},
    ...
  ]
}
```

**Total:** 32 treinos (8 semanas × 4 treinos)

---

## 🎯 Checklist de Validação

- [ ] Prompt tem exemplo explícito de `weekNumber`
- [ ] Schema mostra múltiplas semanas
- [ ] Instruções dizem "SEMPRE inclua weekNumber"
- [ ] Logs mostram `"Semanas: X"` com número correto
- [ ] Biblioteca mostra TODAS as semanas
- [ ] Cada semana tem 3-5 treinos (padrão)

---

## 🚀 Status Atual

### ✅ Implementado:
1. Prompt com instruções explícitas
2. Schema com exemplo de múltiplas semanas
3. Captura do campo `weekNumber` no DTO e Model
4. Logs de debug para verificar

### ⚠️ Pendente Teste:
1. Gerar novo plano e verificar logs
2. Confirmar que biblioteca mostra todas as semanas
3. Se não funcionar, implementar **Opção A** (fallback inteligente)

---

## 💡 Dica Final

Se mesmo com o prompt melhorado a IA continuar falhando, a **Opção A (fallback inteligente)** é a mais robusta porque:

1. ✅ Não depende da IA ser perfeita
2. ✅ Garante que SEMPRE haverá weekNumber
3. ✅ Usa lógica baseada em quantidade de treinos por semana
4. ✅ Funciona mesmo se a IA mandar apenas alguns weekNumber

**Recomendo implementar essa opção como plano B!**

