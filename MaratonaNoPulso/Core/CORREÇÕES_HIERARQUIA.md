# 🏗️ Correções da Estrutura Hierárquica - Plano > Semana > Treino

## 📋 Resumo das Correções

As correções implementadas garantem que os dados dos treinos (distância, duração, intensidade) nunca cheguem zerados ou incompletos ao WorkoutKit, resolvendo o problema de treinos com valores null ou 0 vindos da IA.

---

## ✅ 1. Models.swift - Estrutura de Dados

### O que já estava implementado:
- ✅ `weekNumber` e `parentPlanId` em `DailyPlan`
- ✅ `StrengthParameters` com todos os campos necessários
- ✅ `TrainingPlan` e `TrainingWeek` para hierarquia completa
- ✅ `weekNumber` e `strengthParams` em `AIWorkoutPlan`

### Hierarquia de Pastas:
```
📁 Plano Completo (plan_container)
  └─ 📅 Semana 1 (week_container)
      ├─ 🏃 Treino 1 (running)
      ├─ 💪 Treino 2 (strength)
      └─ 🛌 Treino 3 (rest)
  └─ 📅 Semana 2 (week_container)
      └─ ...
```

---

## ✅ 2. AIService.swift - Inteligência de Fallback

### Mudanças Implementadas:

#### 2.1 SafeWorkoutDTO - Novos Campos
```swift
struct SafeWorkoutDTO: Decodable {
    // Campos básicos
    let title: String?
    let distance: Double?
    let duration: Int?
    
    // 🆕 Organização hierárquica
    let weekNumber: Int?
    
    // 🆕 Parâmetros de força
    let sets: Int?
    let reps: String?
    let restSeconds: Int?
    let exercises: [String]?
    let strengthNotes: String?
    
    // 🆕 Campos adicionais
    let cycleTarget: String?
    let workoutReasoning: String?
    let safetyWarning: String?
    let zoneFocus: String?
    let difficultyRating: String?
}
```

#### 2.2 WeekMapper - Engenharia de Fallback

**Lógica de Inferência Inteligente:**

1. **Descanso** (`rest`):
   - distance = 0, duration = 0 ✅

2. **Treino de Força** (`strength`):
   - distance = 0
   - duration = 45 min (padrão se não especificado)
   - Cria `StrengthParameters` automaticamente ✅

3. **Corrida/Cardio**:
   - Se ambos zerados → `5km / 30min` (valores padrão)
   - Se só tem distância → calcula duração (`dur = dist * 6`)
   - Se só tem duração → calcula distância (`dist = dur / 6`)

**Log detalhado para debugging:**
```
📄 JSON PREVIEW: {...}
✅ Decodificado: 14 treinos
   ℹ️ 'Long Run Semana 1': Inferindo duração de 10.0km -> 60min
   ⚠️ 'Corrida Regenerativa': Dist/Dur zerados, usando fallback: 5.0km / 30min
   ✅ 'Treino de Força': 0km, 45min, Semana 1
📊 RESULTADO: 14 validados, 14 únicos
```

#### 2.3 WeekPromptStrategy - Instruções Melhoradas

**Novos Comandos para a IA:**

```swift
REGRAS OBRIGATÓRIAS:
1. Campos NUMÉRICOS são obrigatórios:
   - "distance": número (km) - Use 0 para descanso ou força
   - "duration": número (minutos) - NUNCA envie null ou 0 para corridas
   - "weekNumber": número (1, 2, 3...) - SEMPRE inclua

2. Para treinos de FORÇA, inclua: sets, reps, restSeconds, exercises
3. Para DESCANSO: distance=0, duration=0, type="rest"
4. Para CORRIDA: distance e duration SEMPRE > 0

VALORES PADRÃO SE NÃO TIVER CERTEZA:
- Corrida Leve: 5km, 30min
- Long Run: 10km, 60min
- Treino de Força: 0km, 45min
- Descanso: 0km, 0min
```

**Exemplo de Schema:**
```json
{
  "workouts": [
    {
      "title": "Corrida Leve",
      "distance": 5.0,
      "duration": 30,
      "weekNumber": 1,
      "type": "outdoor_run"
    },
    {
      "title": "Treino de Força",
      "distance": 0,
      "duration": 45,
      "weekNumber": 1,
      "type": "strength",
      "sets": 3,
      "reps": "12-15",
      "restSeconds": 60,
      "exercises": ["Agachamento", "Lunges"]
    }
  ]
}
```

#### 2.4 SegmentMapper - Fallback em Nível de Segmento

Já existente e funcionando corretamente:
- ✅ Estima duração por tipo de segmento
- ✅ Estima distância por tipo de segmento
- ✅ Injeta pace baseado em intensidade
- ✅ Ignora segmentos completamente inválidos

---

## ✅ 3. VoiceCoachView.swift - Salvamento Hierárquico

### Fluxo de Salvamento:

```swift
func saveBatch(workouts: [AIWorkoutPlan]) {
    let parentPlanId = UUID()
    
    // 1️⃣ Criar Plano PAI
    let parentPlan = DailyPlan(
        id: parentPlanId,
        activityType: "plan_container",
        title: "Meia Maratona - 8 Semanas",
        parentPlanId: nil  // É o pai
    )
    
    // 2️⃣ Agrupar treinos por semana
    let groupedByWeek = Dictionary(grouping: workouts) { $0.weekNumber ?? 1 }
    
    // 3️⃣ Para cada semana, criar container
    for weekNum in sortedWeeks {
        let weekPlan = DailyPlan(
            activityType: "week_container",
            weekNumber: weekNum,
            parentPlanId: parentPlanId  // Pertence ao plano pai
        )
        
        // 4️⃣ Adicionar treinos da semana
        for workout in weekWorkouts {
            let newPlan = DailyPlan(
                activityType: workout.type,  // "running", "strength", "rest"
                strengthParams: workout.strengthParams,  // ✅ Preserva parâmetros
                weekNumber: weekNum,
                parentPlanId: weekPlan.id  // Pertence à semana
            )
        }
    }
}
```

**Logs de debug:**
```
📦 Salvando plano: Meia Maratona - 8 Semanas
   - Total de treinos: 56
   - Semanas: 8
✅ Plano salvo com sucesso!
```

---

## ✅ 4. LibraryView.swift - Visualização e Deleção em Cascata

### Estrutura de Views:

```
LibraryView
  └─ Lista de Planos (plan_container)
       └─ PlanDetailView
            └─ Lista de Semanas (week_container)
                 └─ WeekWorkoutsList
                      └─ Lista de Treinos
                           └─ WorkoutEditorView
```

### Filtragem Inteligente:

```swift
// Planos principais
var trainingPlans: [DailyPlan] {
    savedWorkouts.filter { 
        $0.activityType == "plan_container" && 
        !$0.isArchived 
    }
}

// Treinos avulsos (legado)
var looseWorkouts: [DailyPlan] {
    savedWorkouts.filter { 
        $0.parentPlanId == nil && 
        $0.activityType != "plan_container" && 
        $0.activityType != "week_container" &&
        !$0.isArchived
    }
}
```

### Deleção em Cascata:

```swift
func deletePlan(_ plan: DailyPlan) {
    // 1. Encontra semanas filhas
    let weekIds = savedWorkouts.filter { $0.parentPlanId == plan.id }.map { $0.id }
    
    // 2. Apaga treinos das semanas
    savedWorkouts.removeAll { workout in
        weekIds.contains(workout.parentPlanId ?? UUID())
    }
    
    // 3. Apaga as semanas
    savedWorkouts.removeAll { $0.parentPlanId == plan.id }
    
    // 4. Apaga o plano pai
    savedWorkouts.removeAll { $0.id == plan.id }
}
```

---

## ✅ 5. WorkoutKitManager.swift - Validação Final

### Proteção contra dados inválidos:

```swift
// Ignora segmentos completamente inválidos
if (segment.durationMinutes ?? 0) <= 0 && 
   (segment.distanceKm ?? 0) <= 0 { 
    continue 
}
```

### Fallback se não houver segmentos:

```swift
if blocks.isEmpty {
    let goal: WorkoutGoal
    if let dist = fallbackDistance, dist > 0 { 
        goal = .distance(dist, .kilometers) 
    } else {
        let duration = fallbackDuration > 0 ? Double(fallbackDuration) : 30.0
        goal = .time(duration, .minutes)
    }
    blocks.append(IntervalBlock(steps: [IntervalStep(.work, goal: goal)], iterations: 1))
}
```

---

## 🎯 Resultados Esperados

### Antes:
❌ Treinos com `distance = 0, duration = 0`  
❌ WorkoutKit não consegue criar treino válido  
❌ Hierarquia quebrada na biblioteca  

### Depois:
✅ **Corrida**: Sempre tem distância E duração (inferidos se necessário)  
✅ **Força**: `duration = 45min`, com parâmetros completos (sets, reps, exercises)  
✅ **Descanso**: Corretamente marcado com `0/0`  
✅ **Hierarquia**: Plano → Semanas → Treinos navegável  
✅ **Deleção**: Cascata remove tudo corretamente  

---

## 🔍 Como Testar

1. **Peça um plano completo:**
   - "Crie um plano de 4 semanas para meia maratona"

2. **Verifique os logs:**
   ```
   📄 JSON PREVIEW: {...}
   ✅ Decodificado: 28 treinos
   ℹ️ 'Long Run Semana 1': Inferindo duração...
   ✅ 'Treino de Força': 0km, 45min, Semana 1
   📊 RESULTADO: 28 validados, 28 únicos
   ```

3. **Na biblioteca:**
   - ✅ Ver plano principal
   - ✅ Expandir semanas
   - ✅ Ver treinos com dados válidos
   - ✅ Apagar plano (cascata funciona)

4. **No WorkoutKit:**
   - ✅ Treinos carregam no Apple Watch
   - ✅ Métricas aparecem corretamente

---

## 📚 Arquivos Modificados

1. ✅ **AIService.swift**
   - SafeWorkoutDTO: Novos campos
   - WeekMapper: Lógica de fallback completa
   - WeekPromptStrategy: Instruções melhoradas

2. ✅ **Models.swift**
   - Já tinha todos os campos necessários

3. ✅ **VoiceCoachView.swift**
   - Salvamento hierárquico funcionando
   - Usa `strengthParams` corretamente

4. ✅ **LibraryView.swift**
   - Navegação hierárquica funcionando
   - Deleção em cascata implementada

5. ✅ **WorkoutKitManager.swift**
   - Validação de segmentos funcionando

---

## 🎉 Conclusão

Todas as três frentes foram corrigidas:

1. ✅ **Models**: Campos `weekNumber`, `parentPlanId`, `strengthParams` prontos
2. ✅ **AIService**: Fallback inteligente garante valores válidos sempre
3. ✅ **VoiceCoachView**: Salva hierarquia corretamente
4. ✅ **LibraryView**: Visualiza e apaga hierarquia corretamente

**O sistema agora é robusto contra dados incompletos da IA!** 🚀
