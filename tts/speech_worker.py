#!/usr/bin/env python3
"""常驻语音进程。模型只在第一次用到时加载，之后留在内存里。

stdout 只给 App 读。日志走 stderr。
"""

from __future__ import annotations

import os
import sys

# 协议独占原来的 stdout。库里的 print 改走 stderr，避免把 AUDIO 帧打乱。
_PROTOCOL_FD = os.dup(1)
os.dup2(2, 1)
_protocol = os.fdopen(_PROTOCOL_FD, "wb", buffering=0)
sys.stdout = sys.stderr

import json
import time
import traceback
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent / "models"
SLOW_MS = 1100
KOKORO_VOICE = "af_heart"


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)
    try:
        path = Path.home() / "Library/Application Support/BOTTT/speech.log"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(message + "\n")
    except OSError:
        pass


def write_line(text: str) -> None:
    _protocol.write((text + "\n").encode("utf-8"))
    _protocol.flush()


def pcm16(samples: np.ndarray) -> bytes:
    audio = np.asarray(samples, dtype=np.float32).reshape(-1)
    audio = np.clip(audio, -1.0, 1.0)
    return (audio * 32767.0).astype("<i2").tobytes()


class Engines:
    def __init__(self) -> None:
        self.kokoro = None
        self.piper = None
        self.supertonic = None
        self.supertonic_style = None
        self.fail = {"kokoro": "", "piper": "", "supertonic": ""}

    def status(self) -> dict:
        return {
            "kokoro": self._file_state("kokoro", self._kokoro_ready),
            "piper": self._file_state("piper", self._piper_ready),
            "supertonic": self._file_state("supertonic", self._supertonic_ready),
        }

    def _file_state(self, name: str, ready) -> dict:
        if self.fail[name]:
            return {"state": "error", "reason": self.fail[name]}
        ok, reason = ready()
        if ok:
            return {"state": "files", "reason": ""}
        return {"state": "missing", "reason": reason}

    def _kokoro_ready(self) -> tuple[bool, str]:
        folder = ROOT / "kokoro"
        onnx = folder / "kokoro-v1.0.fp16.onnx"
        voices = folder / "voices-v1.0.bin"
        expected = folder / "expected.json"
        if not expected.is_file():
            return False, "模型还在下载"
        try:
            sizes = json.loads(expected.read_text())
        except json.JSONDecodeError:
            return False, "模型还在下载"
        if not onnx.is_file() or onnx.stat().st_size != int(sizes.get("onnx", -1)):
            return False, "模型还在下载"
        if not voices.is_file() or voices.stat().st_size != int(sizes.get("voices", -1)):
            return False, "模型还在下载"
        return True, ""

    def _piper_ready(self) -> tuple[bool, str]:
        found = find_piper()
        if found is None:
            return False, "模型还在下载"
        return True, ""

    def _supertonic_ready(self) -> tuple[bool, str]:
        cfg = ROOT / "supertonic" / "onnx" / "tts.json"
        if not cfg.is_file():
            return False, "模型还在下载"
        return True, ""

    def ensure(self, name: str):
        if name == "kokoro":
            if self.kokoro is None:
                self.kokoro = load_kokoro()
                warmup_kokoro(self.kokoro)
            return self.kokoro
        if name == "piper":
            if self.piper is None:
                self.piper = load_piper()
                warmup_piper(self.piper)
            return self.piper
        if name == "supertonic":
            if self.supertonic is None:
                self.supertonic, self.supertonic_style = load_supertonic()
                warmup_supertonic(self.supertonic, self.supertonic_style)
            return self.supertonic
        raise RuntimeError(f"未知插件 {name}")

    def stream(self, name: str, text: str):
        engine = self.ensure(name)
        started = time.perf_counter()
        for samples, sample_rate in iter_audio(name, engine, text, self):
            elapsed = int((time.perf_counter() - started) * 1000)
            yield elapsed, int(sample_rate), np.asarray(samples, dtype=np.float32).reshape(-1)


def find_piper():
    root = ROOT / "piper"
    if not root.is_dir():
        return None
    for model in root.rglob("*.onnx"):
        tokens = model.parent / "tokens.txt"
        data = model.parent / "espeak-ng-data"
        if tokens.is_file() and data.is_dir():
            return model, tokens, data
    return None


def load_kokoro():
    import onnxruntime as rt
    from kokoro_onnx import Kokoro

    folder = ROOT / "kokoro"
    model = str(folder / "kokoro-v1.0.fp16.onnx")
    voices = str(folder / "voices-v1.0.bin")
    options = rt.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    options.graph_optimization_level = rt.GraphOptimizationLevel.ORT_ENABLE_ALL
    available = rt.get_available_providers()
    providers = [item for item in ("CoreMLExecutionProvider", "CPUExecutionProvider") if item in available]
    try:
        session = rt.InferenceSession(model, sess_options=options, providers=providers or ["CPUExecutionProvider"])
        log("kokoro providers " + ",".join(session.get_providers()))
        return Kokoro.from_session(session, voices)
    except Exception as exc:
        log(f"kokoro coreml session failed: {exc}")
        return Kokoro(model, voices)


def warmup_kokoro(kokoro) -> None:
    for _samples, _rate in iter_kokoro(kokoro, "Hi."):
        pass


def iter_kokoro(kokoro, text: str):
    import asyncio

    loop = asyncio.new_event_loop()
    stream = kokoro.create_stream(text, voice=KOKORO_VOICE, speed=1.0, lang="en-us")
    try:
        while True:
            try:
                samples, rate = loop.run_until_complete(stream.__anext__())
            except StopAsyncIteration:
                break
            yield samples, rate
    finally:
        loop.close()


def load_piper():
    import sherpa_onnx

    found = find_piper()
    if found is None:
        raise RuntimeError("模型还在下载")
    model, tokens, data = found
    config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=str(model),
                tokens=str(tokens),
                data_dir=str(data),
            ),
            num_threads=2,
            provider="cpu",
        )
    )
    if not config.validate():
        raise RuntimeError("Sherpa-ONNX 不接受这个 Piper 模型")
    return sherpa_onnx.OfflineTts(config)


def warmup_piper(tts) -> None:
    tts.generate("Hi.", sid=0, speed=1.0)


def iter_piper(tts, text: str):
    audio = tts.generate(text, sid=0, speed=1.0)
    yield audio.samples, audio.sample_rate


def load_supertonic():
    from supertonic import TTS

    tts = TTS(
        model="supertonic-3",
        model_dir=str(ROOT / "supertonic"),
        auto_download=False,
        intra_op_num_threads=2,
        inter_op_num_threads=1,
    )
    style = None
    for name in ("F1", "M1"):
        try:
            style = tts.get_voice_style(name)
            break
        except Exception:
            continue
    if style is None:
        raise RuntimeError("Supertonic 没有可用的英文音色")
    return tts, style


def warmup_supertonic(tts, style) -> None:
    tts.synthesize("Hi.", voice_style=style, lang="en", total_steps=5)


def iter_supertonic(tts, text: str, style):
    wav, _duration = tts.synthesize(text, voice_style=style, lang="en", total_steps=5)
    audio = np.asarray(wav, dtype=np.float32).reshape(-1)
    yield audio, 44100


def iter_audio(name: str, engine, text: str, engines: Engines):
    if name == "kokoro":
        return iter_kokoro(engine, text)
    if name == "piper":
        return iter_piper(engine, text)
    if name == "supertonic":
        return iter_supertonic(engine, text, engines.supertonic_style)
    raise RuntimeError(f"未知插件 {name}")


def probe(engines: Engines, name: str) -> None:
    state = engines.status()[name]
    if state["state"] != "files":
        write_line(f"PROBE {name} missing {state['reason']}")
        return
    try:
        first_ms = None
        for elapsed, _rate, _audio in engines.stream(name, "Hi."):
            if first_ms is None:
                first_ms = elapsed
        if first_ms is None:
            raise RuntimeError("没有生成音频")
    except Exception as exc:
        reason = str(exc).replace("\n", " ")[:180]
        engines.fail[name] = reason
        log(traceback.format_exc())
        write_line(f"PROBE {name} fail {reason}")
        return
    kind = "slow" if first_ms > SLOW_MS else "ok"
    if kind == "slow":
        engines.fail[name] = f"首包 {first_ms}ms，超过大约 1 秒"
    log(f"probe {name} {kind} {first_ms}ms")
    write_line(f"PROBE {name} {kind} {first_ms}")


def say(engines: Engines, name: str, text: str) -> None:
    if name == "supertonic":
        log("say supertonic steps=5")
    else:
        log(f"say {name}")
    state = engines.status()[name]
    if state["state"] != "files":
        reason = state["reason"] or "不可用"
        log(f"say fail {name} {reason}")
        write_line("FAIL " + reason)
        return
    sent = False
    try:
        for first_ms, rate, audio in engines.stream(name, text):
            # 短句探测已经量过首包。这里整段一起生成，长句子会超过 1 秒，不能据此拒读。
            payload = pcm16(audio)
            write_line(f"AUDIO {rate} {first_ms} {len(payload)}")
            _protocol.write(payload)
            _protocol.flush()
            log(f"audio {name} rate={rate} first_ms={first_ms} bytes={len(payload)}")
            sent = True
    except Exception as exc:
        reason = str(exc).replace("\n", " ")[:180]
        engines.fail[name] = reason
        log(traceback.format_exc())
        write_line("FAIL " + reason)
        return
    if not sent:
        write_line("FAIL 没有生成音频")
        return
    write_line("END")


def main() -> None:
    engines = Engines()
    log("worker ready")
    write_line("READY")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            write_line("FAIL 请求不是 JSON")
            continue
        command = message.get("cmd")
        if command == "status":
            write_line("STATUS " + json.dumps(engines.status(), ensure_ascii=False))
        elif command == "probe":
            probe(engines, str(message.get("engine", "")))
        elif command == "say":
            say(engines, str(message.get("engine", "")), str(message.get("text", "")))
        elif command == "stop":
            write_line("STOPPED")
        else:
            write_line("FAIL 未知命令")


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
    except Exception:
        log(traceback.format_exc())
        sys.exit(1)
