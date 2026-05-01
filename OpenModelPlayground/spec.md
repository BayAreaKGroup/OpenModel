# ios_models — iOS Edge AI Model Test Harness (Swift)

## 1) Vision

Build a native iOS application in modern Swift (SwiftUI + Swift Concurrency) that lets users download, manage, and run open-source AI models directly on-device (edge-first), and benchmark model behavior across multiple tasks.  
The app is inspired by **Apollo** in its model-first workflow: discover → download → run → compare → iterate.

## 2) Product goals

1. Enable reliable, repeatable on-device model testing without cloud dependency.
2. Provide a clean workflow to download and cache open-source model files locally.
3. Support local inference for at least two model families at launch (chat/text and vision + optional audio/image), with plugin-ready architecture.
4. Keep user data and prompts private by default (no mandatory telemetry/analytics transmission).
5. Expose clear performance signals: latency, memory, storage, and qualitative outputs.

## 3) Target users

- AI practitioners evaluating models for edge deployment.
- Product teams testing lightweight model candidates before backend rollout.
- Developers comparing model quality/performance on iPhone/iPad hardware.

## 4) Non-goals (MVP)

- Full fine-tuning/training pipeline.
- Large-scale model orchestration across multiple devices.
- Hosting models on the app backend.
- Generic “model marketplace” or user-created sharing system.

## 5) Functional requirements

### 5.1 model catalog
- Load available model definitions from a remote metadata source (JSON endpoint).
- Each model entry includes:
  - `id`, `name`, `description`, `license`, `size`, `sha256`, `downloadUrls`, `framework`, `preferredDeviceClass`, `maxContext`, `tokenizer`, `minOS`, `tags`.
- Allow filtering by modality, license, size range, framework, hardware compatibility.
- Pull-to-refresh and stale cache invalidation (TTL).

### 5.2 download and storage
- Download multi-file model bundles (weights, config, tokenizer/token map, optional examples).
- Resume interrupted downloads and support pause/resume/cancel.
- Persist assets in app sandbox under:
  - `Application Support/Models/<modelId>/`
- Verify downloaded content with checksums before activation.
- Track usage status:
  - `available`, `downloading`, `paused`, `downloaded`, `ready`, `error`.
- Storage management UI:
  - per-model size, total used/available space, cleanup for unused or stale models.

### 5.3 model execution / inference
- Support loading/unloading models into runtime.
- Run inference sessions with:
  - model selection
  - prompt/context
  - generation parameters (temperature, maxTokens, topP, system prompt)
  - stop tokens
- Streaming output updates to UI in real time.
- Session controls:
  - start, stop, reset context, save/export conversation snapshot.
- Safety baseline:
  - guard against runaway generation (max generation and timeout caps).

### 5.4 benchmark and comparison
- Built-in benchmark runs:
  - prompt latency (TTFT, time-to-first-token)
  - time per token
  - tokens/sec
  - memory footprint snapshots
  - battery/state-impact indicators when available
- Optional side-by-side run mode:
  - run same prompt on two selected models and compare outputs.

### 5.5 logging and history
- Persist run history:
  - timestamp, model, parameters, prompt summary, latency/quality metrics.
- Optional local logs for debugging (no automatic upload).
- Crash/error capture around model runtime failures.

### 5.6 settings and model compatibility
- Core ML compute preferences (performance/low-power modes where available).
- Max context, quantization preferences, and memory limit hints.
- Framework runtime toggles if multiple engines are available.
- Import/export test scenarios (JSON).

## 6) Technical requirements

### 6.1 platform
- iOS 17+ target (future-proof API use).
- iPhone and iPad support.
- Swift 6 and Xcode 16+ compatible codebase.

### 6.2 architecture
- App uses:
  - **SwiftUI** for UI
  - **Swift Concurrency** (`async/await`, `Actor`, `Task`) for async flows
  - **MVVM + clean layers**:
    - `Domain` (entities + use cases)
    - `Data` (model registry + persistence + download layer)
    - `Inference` (runtime abstraction + engine adapters)
- Dependency injection via lightweight container.
- Single source of truth for state (observable app store/feature stores).

### 6.3 layers
- `CatalogService`
  - sync metadata, cache results, offline fallback.
- `ModelRepository`
  - local model DB + filesystem index.
- `DownloadManager`
  - background-capable download sessions, checksum, resume data.
- `InferenceEngine`
  - protocol-based interface to swap engines:
    - `load(model:)`
    - `generate(prompt:options:)`
    - `stream(...)`
    - `unload(model:)`
- `BenchmarkService`
  - wraps inference with timing and memory probes.
- `StorageManager`
  - quota checks, automatic eviction policies, cleanup tasks.

## 7) Inference runtime strategy (MVP)

The first release should prioritize a proven local runtime path with a robust adapter layer:

- Engine adapter A: Core ML / MLX-backed model execution (primary path when available).
- Engine adapter B: optional fallback runtime for alternate model formats (e.g., GGUF/ggml via native binding or vendored library interface).
- Model metadata must include the runtime requirements and expected file schema so runtime loading can fail early with clear diagnostics.
- Engine abstraction must isolate app logic from runtime details to keep model onboarding cheap.

## 8) Data model

### 8.1 entities
- `ModelMeta`
  - id, name, provider, version, modality, framework, parameters, sizeBytes, files[], checksum, license, requires, recommendedUse.
- `InstalledModel`
  - id, localPath, filesStatus, downloadedAt, lastUsedAt, isOptimized, activeProfileId.
- `RunSession`
  - id, modelId, startedAt, endedAt, prompt, settings, metrics, status.
- `BenchmarkRecord`
  - modelId, scenarioId, promptHash, ttftMs, tokensPerSecond, memoryMB, errors.

### 8.2 persistence
- Use SQLite/Core Data/SwiftData (single implementation choice).
- Keep logs trim-friendly and bounded by user-configured retention.

## 9) UX / UI requirements

### 9.1 tabs
1. **Browse**: search, filter, download, model cards.
2. **Playground**: prompt composer, streaming output, model controls.
3. **Benchmarks**: predefined plus custom scenarios, trend charts.
4. **Library**: installed models, storage and cleanup.
5. **Settings**: runtime prefs, storage, diagnostics, about.

### 9.2 interaction requirements
- Minimal-friction first-run wizard:
  - required model download
  - storage permission explanation
  - one simple sample prompt
- Visual indicators:
  - model status chips, progress bars, runtime status, benchmark badges.
- Offline fallback:
  - if no network, show installed models only and disable catalog actions requiring sync.

## 10) Security and privacy

- No user prompt or output telemetry leaves device by default.
- No hardcoded API keys or third-party SDKs collecting data unless explicitly opted in.
- Download integrity verification mandatory (hash checks).
- All downloaded files are sandboxed and scanned through app-level integrity checks.
- Provide transparent license and model-card metadata before download.
- Optional crash logs may include model/runtime metadata only, no raw prompt payload by default.

## 11) Performance targets (MVP acceptance criteria)

- First interactive load under practical limit for iPhone 14+.
- Smooth streaming UI at 60fps under normal use (non-blocking inference).
- Progress and error states visible for all async operations.
- Recover gracefully from insufficient disk/RAM and unsupported runtime.
- Benchmark accuracy must include wall-clock and output-length-adjusted latency.

## 12) Testing plan

- Unit tests:
  - catalog parsing, checksum validation, benchmark calculations, prompt/session state transitions.
- Integration tests:
  - model download lifecycle, resume behavior, runtime load/unload, multi-model comparison path.
- UX tests:
  - offline mode, low storage behavior, stop generation, restart recovery.
- Device tests:
  - at least two hardware classes (A/B), memory-constrained and normal.

## 13) Deployment and distribution

- Internal TestFlight only initially with feature-flagged experimental runtimes.
- Gradual expansion of supported model families after runtime stability.
- CI checks:
  - lint/build + static analysis
  - reproducible model metadata schema validation
  - basic startup smoke test.

## 14) Roadmap

### MVP (v0.x)
- Catalog + download + one working text model runtime + playground + basic benchmarks.

### v1.0
- Expanded benchmark library, exportable test cases, robust background download recovery.

### v1.1
- Vision model execution path in the same abstraction, side-by-side benchmark comparison.

### v1.2
- Advanced scheduling and optimization presets, user-defined benchmark suites.

## 15) Risks and mitigations

- Runtime binary licensing/import restrictions → strictly curate compatible runtimes and license text before distribution.
- Hardware fragmentation (RAM/ANE capabilities) → capability detection and capability-aware filtering.
- Large file download failures → chunked downloads, retries with backoff, clear per-file status.
- App size growth from embedded model examples → keep runtime binaries small; avoid bundling large models.
- Model quality variance → include model metadata quality notes and standardized benchmark prompts.

## 16) Open questions

- Final runtime choice for first text model path (Core ML only vs adapter chain).
- Official metadata schema source and refresh policy.
- Whether to support user-imported model files from Files app in phase 1.
- Which benchmark datasets/scenarios are highest priority for v0.x.

## 17) Definition of done

- App can:
  - discover model metadata from remote catalog,
  - download at least one open-source model,
  - verify integrity,
  - run on-device inference with streaming output,
  - save session + benchmark data locally,
  - allow cleanup and model deletion,
  - survive app restarts and poor network conditions without corrupting model state.

## 18) Where to download open-source models for iOS edge runtime

Use this stack as the primary model procurement path:

- Hugging Face Hub by format:
  - GGUF models: `https://huggingface.co/models?library=gguf`
  - Core ML models: `https://huggingface.co/models?library=coreml`
  - MLX models: `https://huggingface.co/models?library=mlx`
- Hugging Face GGUF docs for compatibility details: `https://huggingface.co/docs/hub/en/gguf`
- Core ML docs for on-device execution model integration: `https://developer.apple.com/documentation/CoreML`
- Core ML community hub of converted models: `https://huggingface.co/coreml-community`

Operational guidance:

- Prefer `.gguf` for llama.cpp-compatible text models and `.mlmodel` / `.mlpackage` for Core ML execution.
- Verify licenses and file integrity (`sha256`) before activation.
- Store only small/quantized variants for first launch (mobile class-first).

Sample model list for v0.x (by source and likely iOS-friendly starter family):

- GGUF (text, lightweight start)
  - `TheBloke/Llama-2-7B-Chat-GGUF` (chat)  
  - `TheBloke/Mixtral-8x7B-Instruct-v0.1-GGUF`
  - `TheBloke/Qwen2.5-0.5B-Instruct-GGUF` (or another 3B-and-below instruction model)
  - `TheBloke/Qwen2.5-3B-Instruct-GGUF`
- Core ML (Apple ecosystem ready)
  - `apple/FastVLM-0.5B-fp16` (if multimodal stack is enabled)
  - `mlboydaisuke/gemma-4-E2B-coreml`
  - `argmaxinc/whisperkit-coreml` (speech transcription baseline)
  - additional ASR/TTS entries can be selected from `huggingface.co/models?library=coreml` after benchmarking
- MLX (for iOS via MLX runtime/adapter path)
  - `mlx-community/Qwen3.6-27B-4bit` (for larger-device path)
  - `mlx-community/Qwen3.5-27B-Claude-4.6-Opus-Distilled-MLX-4bit`
  - `mlx-community/deepseek-ai-DeepSeek-V4-Flash-2bit-DQ`

Validation rule for any catalog item:

- Must expose files with the exact runtime-compatible format.
- Must include tokenizer/vision processor (if applicable) in a clearly named package.
- Must include license metadata and terms compatible with redistribution/bundled-test usage.
