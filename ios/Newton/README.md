# Newton iOS (Swift & SwiftUI Native App)

Una aplicación 100% nativa para iOS construida con **Swift 5/6** y **SwiftUI**, diseñada con el estilo y estética de Newton (Everforest & Sand).

---

## 🌟 Características Principales

- **Streaming en tiempo real**: Visualización palabra por palabra token a token mediante `URLSession` con Server-Sent Events (SSE) y `AsyncThrowingStream`.
- **Multi-Proveedor & BYOK**:
  - OpenRouter
  - OpenAI (GPT-4o, o3-mini, etc.)
  - Anthropic (Claude 3.7 Sonnet, Claude 3.5 Sonnet, Haiku, Opus)
  - OpenAI Compatible (LM Studio, vLLM, Ollama o proxies en tu red local)
  - Anthropic Compatible (proxies o gateways de Anthropic)
  - Google Gemini, Groq, DeepSeek, Ollama.
- **Almacenamiento Seguro en Enclave Hardware (Keychain)**: Tus API keys se guardan cifradas en el **iOS Keychain** del dispositivo (Zero-Knowledge).
- **Razonamiento Visible (`<think>`)**: Bloques de razonamiento colapsables para modelos como DeepSeek-R1 y Claude 3.7.
- **Motor de Orbits**: Detección y ejecución de herramientas locales (búsqueda web, calculadora, hora).
- **Diseño Adaptativo**: `NavigationSplitView` optimizado tanto para **iPhone** como para **iPad**.
- **Respuesta Háptica**: Integración con el Taptic Engine de Apple (`UIImpactFeedbackGenerator`).

---

## 🚀 Cómo Abrir y Ejecutar el Proyecto en Xcode

1. **Abrir el proyecto**:
   Haz doble clic en el archivo del proyecto o ejecuta en la terminal:
   ```bash
   open ios/Newton/Newton.xcodeproj
   ```

2. **Seleccionar Destino**:
   En la barra superior de Xcode, selecciona tu dispositivo físico (iPhone/iPad) o un simulador (ej: *iPhone 16 Pro*).

3. **Ejecutar**:
   Presiona `Cmd + R` para compilar y lanzar la aplicación.

---

## 📁 Estructura del Código

- **`Models/`**:
  - `Message.swift`: Modelo de mensaje con estados de streaming, bloques de razonamiento y resultados de Orbits.
  - `Conversation.swift`: Sesión de chat.
  - `AIProvider.swift`: Definición de proveedores y protocolos.
  - `AIModel.swift`: Catálogo de modelos predefinidos y dinámicos.
- **`Services/`**:
  - `LLMService.swift`: Cliente HTTP asíncrono con streaming SSE.
  - `KeychainManager.swift`: Gestor seguro de Keychain.
  - `SettingsManager.swift`: Estado observable de configuración.
  - `OrbitEngine.swift`: Motor de herramientas y búsqueda web.
  - `StorageManager.swift`: Persistencia local en Documentos (JSON).
- **`Views/`**:
  - `MainView.swift`: Contenedor principal con barra lateral y detalle.
  - `Chat/ChatView.swift`: Interfaz de chat interactivo.
  - `Chat/MessageBubbleView.swift`: Burbujas de mensaje con soporte Markdown.
  - `Chat/MessageInputBar.swift`: Barra de entrada con atajos de Orbits.
  - `Settings/SettingsView.swift`: Panel de configuración y prueba de conexión.
  - `Settings/ModelPickerSheet.swift`: Selector y campo para modelos personalizados.
- **`Utilities/`**:
  - `Theme.swift`: Paleta de colores Newton (Everforest & Sand).
  - `Haptics.swift`: Control de vibraciones hápticas.
