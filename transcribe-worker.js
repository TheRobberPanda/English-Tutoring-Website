// Transcription worker for admin.html's lesson recorder.
//
// Runs Whisper on Paulo's own machine through transformers.js, so lesson
// audio never leaves his computer (no processor to disclose, nothing to
// pay). A module worker keeps the page responsive while the model runs.
//
// The page does the segmentation (one utterance at a time, silence already
// cut out) and sends 16 kHz mono Float32 audio; this worker only turns each
// piece into text. Whisper hallucinates stock phrases on silence, which is
// why silence never reaches it.
//
// Served with the admin page's relaxed CSP (see vercel.json): it needs
// 'wasm-unsafe-eval' and connect-src to Hugging Face for the model files,
// which are cached by the browser after the first download.

import { pipeline, env } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.8.1';

env.allowLocalModels = false;

const MODELS = {
  // ~560 MB at 4-bit, needs WebGPU. The accurate one.
  precise: 'onnx-community/whisper-large-v3-turbo',
  // ~250 MB at 8-bit, runs on the CPU when there is no WebGPU. Slower per
  // second of audio on a CPU, but always works.
  fast: 'onnx-community/whisper-small'
};

let asr = null;
let loadedKey = null;

async function detectDevice() {
  if (!self.navigator || !navigator.gpu) return { device: 'wasm', f16: false };
  try {
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) return { device: 'wasm', f16: false };
    return { device: 'webgpu', f16: adapter.features.has('shader-f16') };
  } catch (e) {
    return { device: 'wasm', f16: false };
  }
}

async function load(quality) {
  const { device, f16 } = await detectDevice();
  // Without a GPU the large model would take hours; fall back quietly.
  const key = device === 'webgpu' && quality !== 'fast' ? 'precise' : 'fast';
  if (asr && loadedKey === key) return { device, model: key };

  const dtype = device === 'webgpu'
    ? (f16 ? { encoder_model: 'q4f16', decoder_model_merged: 'q4f16' }
           : { encoder_model: 'q4', decoder_model_merged: 'q4' })
    : { encoder_model: 'q8', decoder_model_merged: 'q8' };

  const files = {};
  asr = await pipeline('automatic-speech-recognition', MODELS[key], {
    device,
    dtype,
    progress_callback: p => {
      if (p.status === 'progress' && p.file) {
        files[p.file] = { loaded: p.loaded || 0, total: p.total || 0 };
        const all = Object.values(files);
        const loaded = all.reduce((n, f) => n + f.loaded, 0);
        const total = all.reduce((n, f) => n + f.total, 0);
        self.postMessage({ type: 'download', loaded, total });
      }
    }
  });
  loadedKey = key;
  return { device, model: key };
}

self.onmessage = async (e) => {
  const msg = e.data || {};
  try {
    if (msg.type === 'load') {
      const info = await load(msg.quality);
      self.postMessage({ type: 'ready', id: msg.id, ...info });
    } else if (msg.type === 'transcribe') {
      if (!asr) await load(msg.quality);
      // No language = Whisper detects it per piece, which is what a lesson
      // that switches between Spanish/Polish and English needs.
      const opts = { task: 'transcribe', return_timestamps: false };
      if (msg.language) opts.language = msg.language;
      const out = await asr(msg.audio, opts);
      self.postMessage({ type: 'result', id: msg.id, text: (out && out.text || '').trim() });
    }
  } catch (err) {
    self.postMessage({ type: 'error', id: msg.id, message: String(err && err.message || err) });
  }
};
