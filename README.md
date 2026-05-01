# OpenModel

Curated resources for open-weight AI models — LLM, VLM, audio, and more.

## Contents

### 📊 [Open Weight Model Memory Estimates](open_weight_model_memory_estimates.md)

A comprehensive reference for estimating **inference memory requirements** for open-weight foundation models:

- **Memory formulas** for weight loading (BF16, INT8, Q4 quantization)
- **VRAM vs RAM** comparison with practical estimates for GPU and CPU inference
- **KV-cache calculations** for different context lengths
- **Model tables** covering:
  - Top 5 LLMs (Llama 4, DeepSeek, Qwen, Mistral)
  - Top 5 VLMs (Llama 4 Scout, Qwen2.5-VL, Pixtral)
  - Top 5 Audio models (Qwen2-Audio, Ultravox, MiniCPM-o)
  - Google Gemma 3/3n models
  - Microsoft Phi-4 models
  - Liquid.ai LFM2 models

### 📱 [OpenModelPlayground](OpenModelPlayground/)

A native **iOS/macOS Swift application** for on-device AI model testing:

- Download and manage open-source model files locally
- Run inference directly on device (edge-first, no cloud dependency)
- Benchmark model performance: latency, memory, storage
- Support for multiple model families (chat/text, vision, audio)
- Privacy-first — all data stays on device

See [spec.md](OpenModelPlayground/spec.md) for detailed requirements.

## License

See individual model licenses in the documentation.
