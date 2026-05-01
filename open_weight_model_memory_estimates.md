# Estimating inference memory for open-weight LLM, VLM, audio, and Liquid.ai models

Generated: **2026-05-01**.

## Scope and interpretation

This report estimates **inference-time memory needed to load model weights** for current, high-profile open-weight foundation models. It does **not** estimate training memory. I interpreted “open-source” broadly as **open-weight / openly downloadable** because many leading models use custom community, research, or permissive-but-not-always-OSI licenses.

The tables are **not benchmark rankings**. “Top 5” means a practical selection of recent, large, widely discussed flagship open-weight models in each modality class. Several models appear in more than one category because many recent models are multimodal.

## Formula

### 1. Weight memory

Use the total number of parameters that must be loaded:

$$
M_{\text{weights, GiB}} =
P_{\text{total, billions}}
\times b_{\text{eff, bytes/param}}
\times \frac{10^9}{2^{30}}
$$

Because $10^9 / 2^{30} \approx 0.9313$:

$$
M_{\text{weights, GiB}} \approx
0.9313 \times P_{\text{total}} \times b_{\text{eff}}
$$

**Important for MoE models:** use **total parameters** for memory unless you explicitly offload experts to CPU/NVMe or shard them across devices. The **active parameter count** estimates compute per token, not the full weight memory required when all experts are resident.

### 2. Effective bytes per parameter

| Quantization / dtype | Effective bytes per parameter used here | Notes |
|---|---:|---|
| BF16 / FP16 | 2.00 | Common full-precision inference storage. |
| FP8 / INT8 | 1.00 | Assumes true 8-bit storage. Runtime kernels may keep some tensors at higher precision. |
| Practical 4-bit | 0.55 | 4-bit payload is 0.50 B/param; 0.55 includes a modest allowance for scales/zero-points/packing metadata. |

### 3. Practical minimum memory

For inference, model runtimes also allocate non-weight buffers, graph/workspace memory, routing metadata, embeddings, normalization tensors, and temporary activations. I therefore include a simple “practical minimum” column:

$$
M_{\text{practical}} \approx 1.20 \times M_{\text{weights}}
$$

The tables use **20% overhead** as a conservative starting point. Actual values can be lower or much higher depending on runtime, GPU, tensor parallelism, batch size, and context length.

### 4. KV-cache / context memory

For autoregressive generation, add KV-cache memory:

$$
M_{\text{KV, GiB}} \approx
\frac{B \times T \times L \times 2 \times H_{\text{kv}} \times b_{\text{kv}}}{2^{30}}
$$

Where:

- $B$ = active sequences / batch size.
- $T$ = cached tokens, including image/video/audio tokens after tokenization.
- $L$ = transformer layers.
- $H_{\text{kv}}$ = KV hidden width per layer, often `num_kv_heads × head_dim` under GQA/MQA.
- The factor `2` is for K and V.
- $b_{\text{kv}}$ = bytes per KV element, often 2 for BF16/FP16 KV, 1 for FP8 KV.

Example: batch 1, 32K context, 80 layers, KV width 1024, BF16 KV:

$$
1 \times 32768 \times 80 \times 2 \times 1024 \times 2 / 2^{30} = 10.0 \text{ GiB}
$$

For VLM/audio/video models, modality encoders can also add memory, and long media inputs can add many extra tokens. Treat the table numbers as the **weight-only baseline before KV cache**.

### 5. Sharding rule of thumb

For tensor parallelism across $N$ similar GPUs:

$$
M_{\text{per GPU}} \approx \frac{M_{\text{weights}}}{N} + M_{\text{per-GPU KV}} + M_{\text{runtime overhead}}
$$

MoE sharding can be uneven if experts are not distributed symmetrically.

### 6. VRAM vs. RAM: Understanding memory types

**VRAM (Video RAM)** is memory physically located on the GPU. **RAM (System RAM)** is the main memory accessible by the CPU. For LLM inference:

| Memory Type | Location | Speed | Typical Size | Used For |
|---|---|---|---|---|
| VRAM | GPU | ~1–3 TB/s bandwidth | 8–192 GiB per GPU | Model weights, KV cache, activations during GPU inference |
| RAM | System | ~50–200 GB/s bandwidth | 16–2048 GiB | CPU inference, weight offloading, data preprocessing |

**How memory is used in inference:**

1. **Pure GPU inference:** All weights + KV cache + activations must fit in VRAM. This is the fastest but most constrained.
2. **CPU inference (llama.cpp, etc.):** Model loads into RAM. Slower but can handle larger models on consumer hardware.
3. **Hybrid / offloading:** Weights split between VRAM and RAM; GPU processes layers one at a time, streaming from RAM. Slower than pure GPU but enables larger models.

**Total VRAM required for GPU inference:**

$$
\text{VRAM}_{\text{total}} = M_{\text{weights}} + M_{\text{KV cache}} + M_{\text{activations}}
$$

For practical estimates:

$$
\text{VRAM}_{\text{min}} \approx 1.20 \times M_{\text{weights}} + M_{\text{KV}}
$$

The 20% overhead accounts for activations, graph metadata, and runtime buffers. For typical single-user inference with 32K context:

$$
\text{VRAM}_{\text{32K}} \approx 1.20 \times M_{\text{weights}} + 2\text{–}10 \text{ GiB}
$$

**RAM requirements for CPU inference:**

$$
\text{RAM}_{\text{min}} \approx 1.10 \times M_{\text{weights}} + M_{\text{KV}}
$$

RAM overhead is typically lower (10%) because CPU runtimes have simpler memory management.

**Rule of thumb:** If your GPU has $V$ GiB of VRAM, you can run models where:

$$
M_{\text{weights}} < 0.75 \times V
$$

This leaves ~25% headroom for KV cache and activations.

## Headline practical Q4 minimums

These are the estimated 4-bit weight load requirements with 20% overhead and **without** KV-cache.

| Category | Model | P_total (B) | Active (B) | Q4 Weights (GiB) | Min VRAM Q4 (GiB) | VRAM Q4 + 32K ctx (GiB) | Min RAM for CPU (GiB) |
|---|---|---|---|---|---|---|---|
| LLM | DeepSeek-V4-Pro | 1600 | 49 | 819.6 | 983.5 | 993.5 | 901.6 |
| LLM | Kimi-K2.6 | 1000 | 32 | 512.2 | 614.7 | 624.7 | 563.4 |
| LLM | GLM-5.1 | 744 | 40 | 381.1 | 457.3 | 467.3 | 419.2 |
| LLM | Llama 4 Maverick | 400 | 17 | 204.9 | 245.9 | 255.9 | 225.4 |
| LLM | Qwen3.5-397B-A17B | 397 | 17 | 203.4 | 244.0 | 254.0 | 223.7 |
| VLM | Kimi-K2.6 | 1000 | 32 | 512.2 | 614.7 | 624.7 | 563.4 |
| VLM | Llama 4 Maverick | 400 | 17 | 204.9 | 245.9 | 255.9 | 225.4 |
| VLM | Qwen3.5-397B-A17B | 397 | 17 | 203.4 | 244.0 | 254.0 | 223.7 |
| VLM | Qwen3-VL-235B-A22B | 236 | 22 | 120.9 | 145.1 | 155.1 | 133.0 |
| VLM | InternVL3.5-241B-A28B | 240.7 | 28 | 123.3 | 148.0 | 158.0 | 135.6 |
| Audio | Nemotron 3 Nano Omni 30B | 30 | 3 | 15.4 | 18.4 | 22.4 | 16.9 |
| Audio | Qwen3-Omni-30B-A3B | 30 | 3 | 15.4 | 18.4 | 22.4 | 16.9 |
| Audio | Mistral Voxtral Small | 24 | 24 | 12.3 | 14.8 | 18.8 | 13.5 |
| Audio | MiniCPM-o 4.5 | 9 | 9 | 4.6 | 5.5 | 9.5 | 5.1 |
| Audio | Phi-4-multimodal | 5.6 | 5.6 | 2.9 | 3.4 | 7.4 | 3.2 |

## Top 5 open-weight LLMs

| Model | Modality | Params P_total (B) | Active (B) | Arch | BF16 (GiB) | INT8 (GiB) | Q4 (GiB) | Min VRAM Q4 (GiB) | VRAM Q4+32K (GiB) | Min RAM CPU (GiB) | Notes | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| DeepSeek-V4-Pro | Text | 1600 | 49 | MoE | 2,980.2 | 1,490.1 | 819.6 | 983.5 | 993.5 | 901.6 | 1.6T total / 49B active; open-weight. | [DeepSeek](https://api-docs.deepseek.com/news/news260424) |
| Kimi-K2.6 | Text + vision | 1000 | 32 | MoE | 1,862.6 | 931.3 | 512.2 | 614.7 | 624.7 | 563.4 | 1T total / 32B activated. | [Moonshot HF](https://huggingface.co/moonshotai/Kimi-K2.6) |
| GLM-5.1 | Text | 744 | 40 | MoE | 1,385.8 | 692.9 | 381.1 | 457.3 | 467.3 | 419.2 | 744B total / 40B active. | [Lambda](https://lambda.ai/inference-models/zai-org/glm-5.1) |
| Llama 4 Maverick | Text + vision | 400 | 17 | MoE | 745.1 | 372.5 | 204.9 | 245.9 | 255.9 | 225.4 | 400B total / 17B active. | [Meta Llama](https://www.llama.com/docs/model-cards-and-prompt-formats/llama4/) |
| Qwen3.5-397B-A17B | Text + vision | 397 | 17 | MoE | 739.5 | 369.7 | 203.4 | 244.0 | 254.0 | 223.7 | 397B total / 17B activated. | [Qwen HF](https://huggingface.co/Qwen/Qwen3.5-397B-A17B) |

## Top 5 open-weight VLMs

| Model | Modality | Params P_total (B) | Active (B) | Arch | BF16 (GiB) | INT8 (GiB) | Q4 (GiB) | Min VRAM Q4 (GiB) | VRAM Q4+32K (GiB) | Min RAM CPU (GiB) | Notes | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Kimi-K2.6 | Image + text | 1000 | 32 | MoE + MoonViT | 1,862.6 | 931.3 | 512.2 | 614.7 | 624.7 | 563.4 | 1T total / 32B activated; MoonViT encoder. | [Moonshot HF](https://huggingface.co/moonshotai/Kimi-K2.6) |
| Llama 4 Maverick | Image + text | 400 | 17 | MoE multimodal | 745.1 | 372.5 | 204.9 | 245.9 | 255.9 | 225.4 | Native multimodal, 400B/17B. | [Meta Llama](https://www.llama.com/docs/model-cards-and-prompt-formats/llama4/) |
| Qwen3.5-397B-A17B | Image + text | 397 | 17 | MoE + vision | 739.5 | 369.7 | 203.4 | 244.0 | 254.0 | 223.7 | 397B total / 17B active. | [Qwen HF](https://huggingface.co/Qwen/Qwen3.5-397B-A17B) |
| Qwen3-VL-235B-A22B | Image/video + text | 236 | 22 | MoE VLM | 439.6 | 219.8 | 120.9 | 145.1 | 155.1 | 133.0 | 236B total. | [Qwen HF](https://huggingface.co/Qwen/Qwen3-VL-235B-A22B-Instruct) |
| InternVL3.5-241B-A28B | Image/video + text | 240.7 | 28 | MoE MLLM | 448.3 | 224.2 | 123.3 | 148.0 | 158.0 | 135.6 | 240.7B/28B; 5.5B vision params. | [OpenGVLab](https://github.com/OpenGVLab/InternVL) |

## Top 5 open-weight audio / omni-audio foundation models

| Model | Modality | Params P_total (B) | Active (B) | Arch | BF16 (GiB) | INT8 (GiB) | Q4 (GiB) | Min VRAM Q4 (GiB) | VRAM Q4+32K (GiB) | Min RAM CPU (GiB) | Notes | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Nemotron 3 Nano Omni 30B | Audio/video/image/text | 30 | 3 | MoE omni | 55.9 | 27.9 | 15.4 | 18.4 | 22.4 | 16.9 | 30B/3B; speech+vision encoders. | [NVIDIA/AWS](https://aws.amazon.com/blogs/machine-learning/deploy-nvidia-nemotron-3-nano-omni-on-amazon-sagemaker-ai/) |
| Qwen3-Omni-30B-A3B | Audio/video/image/text | 30 | 3 | MoE omni | 55.9 | 27.9 | 15.4 | 18.4 | 22.4 | 16.9 | 30B-A3B; audio/video/image/text. | [Qwen HF](https://huggingface.co/Qwen/Qwen3-Omni-30B-A3B-Instruct) |
| Mistral Voxtral Small | Audio + text | 24 | 24 | Dense audio-LM | 44.7 | 22.4 | 12.3 | 14.8 | 18.8 | 13.5 | 24B; speech transcription/translation. | [Mistral](https://mistral.ai/news/voxtral) |
| MiniCPM-o 4.5 | Omni-modal | 9 | 9 | Dense omni | 16.8 | 8.4 | 4.6 | 5.5 | 9.5 | 5.1 | 9B; full-duplex omni-modal. | [OpenBMB](https://openbmb.github.io/MiniCPM-o-Demo/) |
| Phi-4-multimodal | Text/image/audio | 5.6 | 5.6 | Dense multimodal | 10.4 | 5.2 | 2.9 | 3.4 | 7.4 | 3.2 | 5.6B; speech+vision+text. | [Microsoft HF](https://huggingface.co/microsoft/Phi-4-multimodal-instruct) |

## Liquid.ai models

Liquid.ai publishes compact text, vision-language, and audio models. Liquid’s own documentation also lists GGUF, MLX, and ONNX quantization formats for several models, so practical memory may differ by runtime and quantizer.

| Model | Modality | Params P_total (B) | Active (B) | Arch | BF16 (GiB) | INT8 (GiB) | Q4 (GiB) | Min VRAM Q4 (GiB) | VRAM Q4+32K (GiB) | Min RAM CPU (GiB) | Notes | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| LFM2-24B-A2B | Text | 24 | 2.3 | MoE hybrid | 44.7 | 22.4 | 12.3 | 14.8 | 18.8 | 13.5 | 24B/2.3B active. | [Liquid](https://www.liquid.ai/blog/lfm2-24b-a2b) |
| LFM2-8B-A1B | Text | 8.3 | 1.5 | MoE hybrid | 15.5 | 7.7 | 4.3 | 5.1 | 9.1 | 4.7 | 8.3B/1.5B active. | [Liquid HF](https://huggingface.co/LiquidAI/LFM2-8B-A1B) |
| LFM2-2.6B | Text | 2.6 | 2.6 | Dense hybrid | 4.8 | 2.4 | 1.3 | 1.6 | 5.6 | 1.4 | 2.6B dense. | [Liquid](https://docs.liquid.ai/lfm/models/complete-library) |
| LFM2.5-1.2B | Text | 1.2 | 1.2 | Dense hybrid | 2.2 | 1.1 | 0.6 | 0.7 | 4.7 | 0.7 | 1.2B LFM2.5. | [Liquid](https://www.liquid.ai/models) |
| LFM2-VL-3B | Vision-language | 3 | 3 | Dense VLM | 5.6 | 2.8 | 1.5 | 1.8 | 5.8 | 1.7 | 3B VLM. | [Liquid](https://www.liquid.ai/models) |
| LFM2.5-VL-1.6B | Vision-language | 1.6 | 1.6 | Dense VLM | 3.0 | 1.5 | 0.8 | 1.0 | 5.0 | 0.9 | 1.6B VLM. | [Liquid](https://www.liquid.ai/models) |
| LFM2.5-Audio-1.5B | Audio | 1.5 | 1.5 | Dense audio | 2.8 | 1.4 | 0.8 | 0.9 | 4.9 | 0.9 | 1.5B audio. | [Liquid](https://www.liquid.ai/models) |

## Google Gemma models

| Model | Modality | Params P_total (B) | Active (B) | Arch | BF16 (GiB) | INT8 (GiB) | Q4 (GiB) | Min VRAM Q4 (GiB) | VRAM Q4+32K (GiB) | Min RAM CPU (GiB) | Notes | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gemma 3 27B | Image + text | 27 | 27 | Dense VLM | 50.3 | 25.1 | 13.8 | 16.6 | 20.6 | 15.2 | Flagship Gemma 3; image+text. | [Google HF](https://huggingface.co/google/gemma-3-27b-it) |
| Gemma 3 12B | Image + text | 12 | 12 | Dense VLM | 22.4 | 11.2 | 6.1 | 7.4 | 11.4 | 6.7 | Mid-size Gemma 3 with vision. | [Google HF](https://huggingface.co/google/gemma-3-12b-it) |
| Gemma 3 4B | Image + text | 4 | 4 | Dense VLM | 7.5 | 3.7 | 2.0 | 2.5 | 6.5 | 2.2 | Compact Gemma 3 with vision. | [Google HF](https://huggingface.co/google/gemma-3-4b-it) |
| Gemma 3 1B | Text | 1 | 1 | Dense | 1.9 | 0.9 | 0.5 | 0.6 | 4.6 | 0.6 | Smallest Gemma 3 text-only. | [Google HF](https://huggingface.co/google/gemma-3-1b-it) |
| Gemma 3n E4B | Image/video/audio | 8 | 4 | MatFormer | 14.9 | 7.5 | 4.1 | 4.9 | 8.9 | 4.5 | 8B raw / 4B effective; multimodal. | [Google HF](https://huggingface.co/google/gemma-3n-E4B-it) |
| Gemma 3n E2B | Image/video/audio | 4 | 2 | MatFormer | 7.5 | 3.7 | 2.0 | 2.5 | 6.5 | 2.2 | 4B raw / 2B effective; multimodal. | [Google HF](https://huggingface.co/google/gemma-3n-E2B-it) |

## Microsoft Phi models

| Model | Modality | Params P_total (B) | Active (B) | Arch | BF16 (GiB) | INT8 (GiB) | Q4 (GiB) | Min VRAM Q4 (GiB) | VRAM Q4+32K (GiB) | Min RAM CPU (GiB) | Notes | Source |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Phi-4 | Text | 14 | 14 | Dense | 26.1 | 13.0 | 7.2 | 8.6 | 12.6 | 7.9 | 14B; math/reasoning focus; 16K ctx. | [Microsoft HF](https://huggingface.co/microsoft/phi-4) |
| Phi-4-multimodal | Text/image/audio | 5.6 | 5.6 | Dense multimodal | 10.4 | 5.2 | 2.9 | 3.4 | 7.4 | 3.2 | 5.6B; speech+vision+text; 128K ctx. | [Microsoft HF](https://huggingface.co/microsoft/Phi-4-multimodal-instruct) |
| Phi-4-mini | Text | 3.8 | 3.8 | Dense | 7.1 | 3.5 | 1.9 | 2.3 | 6.3 | 2.1 | 3.8B; 128K ctx; 23 languages. | [Microsoft HF](https://huggingface.co/microsoft/Phi-4-mini-instruct) |

## Practical takeaways

1. **Use total parameters for VRAM/RAM sizing.** Active parameters are excellent for estimating token-time compute in MoE models, but all resident experts still occupy memory.
2. **4-bit does not mean exactly 0.5 bytes/parameter in practice.** Group scales, zero points, padding, and runtime buffers add overhead.
3. **KV cache can dominate small models and long-context workloads.** A 5–30B model at 4-bit may fit easily, but a 128K context, multiple concurrent users, or image/video/audio tokens can add tens of GiB.
4. **For very large MoE models, expert offload is the main lever.** Without offload or many GPUs, 400B–1.6T parameter models remain hundreds of GiB even at 4-bit.
5. **Multimodal estimates are lower bounds when model cards report only language-backbone parameters.** The tables use published total parameter counts where available.

## Source links used

- [DeepSeek V4 Preview Release](https://api-docs.deepseek.com/news/news260424)
- [Kimi-K2.6 model card](https://huggingface.co/moonshotai/Kimi-K2.6)
- [GLM-5.1 deployment/spec reference](https://lambda.ai/inference-models/zai-org/glm-5.1)
- [Meta Llama 4 model card / docs](https://www.llama.com/docs/model-cards-and-prompt-formats/llama4/)
- [Qwen3.5-397B-A17B model card](https://huggingface.co/Qwen/Qwen3.5-397B-A17B)
- [Qwen3-VL-235B-A22B-Instruct model card](https://huggingface.co/Qwen/Qwen3-VL-235B-A22B-Instruct)
- [InternVL repository](https://github.com/OpenGVLab/InternVL)
- [NVIDIA Nemotron 3 Nano Omni deployment article](https://aws.amazon.com/blogs/machine-learning/deploy-nvidia-nemotron-3-nano-omni-on-amazon-sagemaker-ai/)
- [Qwen3-Omni-30B-A3B-Instruct model card](https://huggingface.co/Qwen/Qwen3-Omni-30B-A3B-Instruct)
- [Mistral Voxtral announcement](https://mistral.ai/news/voxtral)
- [MiniCPM-o 4.5 demo/model page](https://openbmb.github.io/MiniCPM-o-Demo/)
- [Microsoft Phi-4 model card](https://huggingface.co/microsoft/phi-4)
- [Microsoft Phi-4-multimodal-instruct model card](https://huggingface.co/microsoft/Phi-4-multimodal-instruct)
- [Microsoft Phi-4-mini-instruct model card](https://huggingface.co/microsoft/Phi-4-mini-instruct)
- [Google Gemma 3 collection](https://huggingface.co/collections/google/gemma-3-release-67c6c6f89c4f76621268bb6d)
- [Google Gemma 3n E4B model card](https://huggingface.co/google/gemma-3n-E4B-it)
- [Google Gemma 3n documentation](https://ai.google.dev/gemma/docs/gemma-3n)
- [Liquid.ai models page](https://www.liquid.ai/models)
- [Liquid.ai complete model library](https://docs.liquid.ai/lfm/models/complete-library)
- [Liquid LFM2-8B-A1B model card](https://huggingface.co/LiquidAI/LFM2-8B-A1B)
- [Liquid LFM2-24B-A2B announcement](https://www.liquid.ai/blog/lfm2-24b-a2b)