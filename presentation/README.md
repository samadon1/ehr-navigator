# EHR Navigator - Presentation Materials

Simplified code files for teaching/presenting the On-Device AI Agent architecture.

## Files

| File | Topic | Key Concepts |
|------|-------|--------------|
| [01_fhir_models.dart](01_fhir_models.dart) | FHIR Data Standard | Resources, Patient, Condition, Medication, Observation |
| [02_cactus_sdk.dart](02_cactus_sdk.dart) | Cactus SDK | On-device LLM, completion, streaming, embeddings, tool calling |
| [03_agent_pipeline.dart](03_agent_pipeline.dart) | Agent Architecture | 6-phase pipeline, async generator, state machine |
| [04_tool_registry.dart](04_tool_registry.dart) | Tool Definitions | CactusTool format, available tools |
| [05_cds_engine.dart](05_cds_engine.dart) | Clinical Decision Support | Drug interactions, safety alerts |
| [06_three_approaches.dart](06_three_approaches.dart) | Comparison | Agent vs LLM Direct vs RAG |
| [PRESENTATION.md](PRESENTATION.md) | Full Documentation | Complete guide with diagrams |

## Recommended Order

1. **FHIR** (01) - Understand the data structure
2. **Cactus** (02) - How to run LLMs on-device
3. **Tools** (04) - What actions the agent can take
4. **Agent** (03) - The main pipeline
5. **CDS** (05) - Safety layer
6. **Comparison** (06) - Why use Agent vs other approaches

## Key Diagrams

### Agent Pipeline
```
Query → Discovery → Routing(LLM) → Execute → Filter(LLM) → CDS → Synthesize(LLM)
```

### Three Approaches
```
         ┌─────────┐      ┌──────────┐      ┌─────────┐
         │  AGENT  │      │LLM DIRECT│      │   RAG   │
         └────┬────┘      └────┬─────┘      └────┬────┘
              │                │                 │
         3 LLM calls      1 LLM call        1 LLM call
         + Tools          + All data        + Embeddings
         + CDS            in prompt         + Similarity
```

## Notes

- These files are **simplified** for teaching purposes
- They may not compile standalone (missing imports/dependencies)
- See the actual source code in `skillsync/lib/` for the full implementation
