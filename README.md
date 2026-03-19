# EHR Navigator: On-Device AI Agent for Healthcare

An on-device AI agent that navigates Electronic Health Records (EHR) using FHIR standards, with built-in clinical decision support for patient safety.

**All AI inference runs locally on your device - no data leaves the device.**

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![FHIR](https://img.shields.io/badge/FHIR-R4-orange)

---

## What This Project Demonstrates

### 1. On-Device LLM Inference
Using [Cactus SDK](https://pub.dev/packages/cactus) to run language models locally on mobile/desktop - complete privacy, no cloud dependency.

### 2. AI Agent Architecture
A 6-phase pipeline that intelligently routes queries:
```
Query → Discovery → Routing → Execute → Filter → CDS → Synthesize
         (LLM)                          (LLM)        (LLM)
```

### 3. Three AI Approaches Compared
| Approach | Description | Speed | Best For |
|----------|-------------|-------|----------|
| **Agent** | Multi-step with tool calling | ~2.7s | Complex queries, safety-critical |
| **LLM Direct** | All data in prompt | ~1.1s | Simple lookups, prototyping |
| **RAG** | Embedding + similarity search | ~1.5s | Large datasets |

### 4. Clinical Decision Support (CDS)
Rule-based safety checks that catch:
- Drug-drug interactions (e.g., Warfarin + Aspirin)
- Allergy alerts
- Critical lab values

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        USER QUERY                            │
│              "Is the patient's diabetes controlled?"         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  DISCOVERY → ROUTING → EXECUTE → FILTER → CDS → SYNTHESIZE  │
│     │          │         │         │       │        │        │
│   FHIR      LLM #1    Tools     LLM #2   Rules   LLM #3     │
│  manifest   (select)  (fetch)  (extract) (safe)  (answer)   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  "The patient's diabetes is partially controlled.           │
│   HbA1c: 7.2% (target <7%). Currently on Metformin 500mg."  │
│                                                              │
│  ⚠️ ALERT: Drug interaction detected                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites
- Flutter SDK (3.19+)
- macOS, iOS, or Android device
- ~2GB storage for models

### Run the App

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/ehr-navigator.git
cd ehr-navigator/skillsync

# Get dependencies
flutter pub get

# Run on macOS
flutter run -d macos

# Or run on iOS
flutter run -d ios

# Or run on Android
flutter run -d android
```

### First Launch
1. The app will download the AI model (~500MB, one-time)
2. Select a patient from the list
3. Ask questions like:
   - "What medications is the patient taking?"
   - "Are there any drug interactions?"
   - "Is the diabetes controlled?"
   - "Show me the recent lab results"

---

## Project Structure

```
skillsync/
├── lib/
│   ├── models/
│   │   ├── fhir/              # FHIR data models
│   │   │   ├── patient.dart
│   │   │   ├── condition.dart
│   │   │   ├── medication.dart
│   │   │   └── observation.dart
│   │   └── agent/             # Agent state machine
│   │       ├── agent_state.dart
│   │       └── tool_call.dart
│   ├── services/
│   │   ├── agent/             # AI Agent
│   │   │   ├── ehr_agent_service.dart    # Main agent loop
│   │   │   ├── tool_registry.dart        # Tool definitions
│   │   │   ├── tool_executor.dart        # Tool execution
│   │   │   └── comparison_service.dart   # 3-way comparison
│   │   ├── ehr/               # FHIR data layer
│   │   │   ├── fhir_store.dart
│   │   │   └── fhir_query_service.dart
│   │   └── cds/               # Clinical Decision Support
│   │       ├── cds_engine.dart
│   │       └── drug_interaction.dart
│   └── screens/
│       └── ehr/
│           ├── agent_chat_screen.dart    # Main chat UI
│           └── comparison_screen.dart    # Side-by-side comparison
└── assets/
    └── fhir/                  # Sample patient data (Synthea)
        ├── patient_derek.json
        ├── patient_lazaro.json
        └── patient_lola.json
```

---

## Presentation Materials

See the [`presentation/`](presentation/) folder for:

| File | Description |
|------|-------------|
| `PRESENTATION.md` | Full documentation with diagrams |
| `01_fhir_models.dart` | FHIR data structures (simplified) |
| `02_cactus_sdk.dart` | On-device LLM usage |
| `03_agent_pipeline.dart` | Main agent loop |
| `04_tool_registry.dart` | Tool definitions |
| `05_cds_engine.dart` | Drug interaction checking |
| `06_three_approaches.dart` | Agent vs LLM Direct vs RAG |

---

## Key Concepts

### FHIR (Fast Healthcare Interoperability Resources)
Healthcare data standard where everything is a "Resource":
- `Patient` - Demographics
- `Condition` - Diagnoses
- `MedicationRequest` - Prescriptions
- `Observation` - Labs & vitals
- `AllergyIntolerance` - Allergies

### Cactus SDK
On-device LLM inference for Flutter/Dart:
```dart
final model = cactus.CactusLM();
await model.initializeModel(params: CactusInitParams(model: 'qwen3-0.6'));

final result = await model.generateCompletion(
  messages: [ChatMessage(role: 'user', content: 'What medications?')],
  params: CactusCompletionParams(tools: ToolRegistry.tools),
);
```

### Tool Calling
LLM selects which FHIR queries to run:
```dart
// User: "What medications is the patient taking?"
// LLM outputs: get_medications(patient_id: "123")
// Tool fetches: [{name: "Metformin", dosage: "500mg"}]
// LLM synthesizes: "The patient is taking Metformin 500mg."
```

---

## Sample Queries to Try

| Query | What Happens |
|-------|--------------|
| "What medications?" | Fetches active medications |
| "Any allergies?" | Fetches allergy list |
| "Check for drug interactions" | Runs CDS engine |
| "Is the diabetes controlled?" | Fetches conditions + HbA1c + medications |
| "Recent lab results" | Fetches observations |
| "Patient summary" | Fetches everything |

---

## Technologies Used

- **Flutter** - Cross-platform UI
- **Cactus SDK** - On-device LLM inference
- **FHIR R4** - Healthcare data standard
- **Synthea** - Synthetic patient data generator
- **Qwen3-0.6B** - Small language model for on-device

---

## License

MIT License - See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- [Cactus Compute](https://cactuscompute.com/) - On-device inference SDK
- [HL7 FHIR](https://hl7.org/fhir/) - Healthcare data standard
- [Synthea](https://synthetichealth.github.io/synthea/) - Synthetic patient generator
