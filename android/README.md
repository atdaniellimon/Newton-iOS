# Newton Android (Kotlin nativo + Jetpack Compose)

Paridad 1:1 con `ios/Newton`, sin reinterpretar el contrato. Estado actual: **scaffold funcional**
(lógica + shell de app). El UI de chat llega en el siguiente milestone.

## Estructura

```
android/
  settings.gradle.kts, build.gradle.kts, gradle.properties, gradle/libs.versions.toml
  shared/   # Kotlin puro (JVM) — testeable en tu Mac SIN Android SDK ni emulador
    src/main/kotlin/ai/newton/shared/
      AIProvider.kt, Message.kt, Conversation.kt, FileAttachment.kt,
      Workspace.kt, AIModel.kt          # modelos, mismos field names que Swift
      SingularityPrompt.kt              # carga shared/.../singularity_prompt.md
      LLMService.kt                     # streaming SSE multi-proveedor (port de Swift)
      OrbitEngine.kt + OrbitTools.kt    # tags <thinking>/<orbit:*>/<download>, fallback imagen
    src/main/resources/singularity_prompt.md  # extraído verbatim de SettingsManager.swift
    src/test/...                        # LLMServiceTest, OrbitEngineTest, ContractTest
  app/      # Android (requiere SDK solo para compilar el APK, no para la lógica)
    chat/ChatViewModel.kt               # port de ChatView.sendMessage + generateAITitle
    data/SettingsRepository.kt          # DataStore + EncryptedSharedPreferences (Keystore)
    data/ConversationStore.kt           # un JSON por conversación + images/ en archivos
    theme/NewtonTheme.kt                # Everforest & Sand en Material3
    MainActivity.kt                     # placeholder hasta el milestone de chat
```

## Contrato compartido con iOS (no romper)

- `AIProvider.wireValue` == Swift `rawValue` (`openai_compatible`, `anthropic_compatible`, …).
  Provider desconocido → `OPENAI_COMPATIBLE` (igual que el fallback Swift).
- JSON de `Conversation`/`Message` usa los mismos keys (`modelId`, `isPinned`, `isGhost`,
  `thinkingContent`, `orbitResults`, `isStreaming`…). Timestamps: iOS usa segundos `Double`,
  Android epoch-millis `Long` — convertir en el borde al sincronizar.
- Gramática de tags idéntica: `<think>`/`<thinking>`, `<orbit:nombre>{json}</orbit:nombre>`,
  `<orbit:generate>`, `<download>`, `[ORBIT:…]` legacy, bloques json `{"name","parameters"}`.
- `shared/src/main/resources/singularity_prompt.md` es copia del system prompt iOS.
  Si cambia `SettingsManager.singularitySystemPrompt`, re-extraer (ver `ContractTest`).

## Diferencias deliberadas vs iOS (fixes, no deuda porteada)

1. **Sin endpoint hardcodeado.** `LLMService.effectiveBaseUrl()` cae al default del proveedor
   cuando el setting está vacío. Nunca un túnel fijo.
2. **Sin JSON monolítico ni base64 inline.** Una conversación = un archivo; imágenes en
   `images/` referenciadas por `file://…` o `localPath`.
3. **API keys solo en Keystore** (`EncryptedSharedPreferences`), nunca en DataStore.
4. **Calculadora segura.** Parser aritmético propio en vez de `NSExpression(format:)`
   (el port Swift tiene riesgo de inyección — ver hallazgo iOS #5).

## Probar SIN Android y SIN emulador

Requisitos en tu Mac: JDK 17 + Gradle 8.7 (nada de Android):

```bash
brew install --cask temurin@17
brew install gradle
```

Tests de toda la lógica (SSE con MockWebServer, orbits, contrato):

```bash
cd android
gradle :shared:test
```

El APK se compila en la nube: push → GitHub Actions (`build-android.yml`) corre los tests
y sube el APK debug como artifact. Para probarlo en un Pixel real desde Safari:
Firebase Test Lab / BrowserStack (siguiente paso, sin instalar nada local).

## Milestones siguientes

1. Chat UI Compose (burbujas, ThinkingCard, OrbitCards, input bar) + NavGraph + deep links.
2. Workspaces, memoria persistente, voz, adjuntos con `images/`.
3. Widgets (Glance), notificaciones, PDF con `PdfDocument`.
4. `OrbitTools` Android real (GPS, CalendarContract, recordatorios) — `OrbitEngine` no cambia.
5. Firebase Test Lab + App Distribution en CI.
