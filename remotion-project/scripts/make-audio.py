#!/usr/bin/env python3
"""Builds public/ambient.wav from src/music.json (the same file the video reads),
so every caption and scene change lands on a beat or note. Needs numpy + scipy."""
import json, wave, pathlib
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

root = pathlib.Path(__file__).resolve().parent.parent
m = json.loads((root / "src/music.json").read_text())
SR = 44100
MASTER = 0.26   # overall loudness (peak level of the main body). Lower = quieter.
BEAT = 60 / m["bpm"]; BAR = 4 * BEAT
dur = m["bars"] * BAR
n = int(SR * dur); t = np.arange(n) / SR
hz = lambda p: 440 * 2 ** ((p - 69) / 12)
smooth = lambda x: x * x * (3 - 2 * x)

pad = np.zeros((2, n))
for i, ch in enumerate(m["chords"]):
    start = i * BAR - 0.25 * BEAT           # swell peaks right at the bar line
    end = (i + 1) * BAR if i < len(m["chords"]) - 1 else dur - 1.0
    up = smooth(np.clip((t - start) / (1.1 * BEAT), 0, 1))
    down = 1 - smooth(np.clip((t - end) / (2.2 * BEAT if i < len(m["chords"]) - 1 else 3.0), 0, 1))
    env = up * down
    for j, p in enumerate(ch["voices"]):
        for det, pan in ((-0.07, 0.35), (0.07, 0.65)):
            f = hz(p) * 2 ** (det / 12)
            tone = np.sin(2 * np.pi * f * t + j) + 0.25 * np.sin(2 * np.pi * 2 * f * t) + 0.08 * np.sin(2 * np.pi * 3 * f * t)
            tone *= env * 0.05 * (1 + 0.1 * np.sin(2 * np.pi * 0.11 * t + j))
            pad[0] += tone * (1 - pan); pad[1] += tone * pan
    b = np.sin(2 * np.pi * hz(ch["bass"]) * t) * env * 0.07
    pad += b

bell = np.zeros(n)
for bar, beat, p, vel in m["notes"]:
    i0 = int((bar * BAR + beat * BEAT) * SR); L = int(3.4 * SR); tl = np.arange(L) / SR; f = hz(p)
    b = (np.sin(2 * np.pi * f * tl) + 0.18 * np.sin(2 * np.pi * 2.01 * f * tl) + 0.05 * np.sin(2 * np.pi * 4.1 * f * tl))
    b *= np.exp(-tl * 1.8) * (1 - np.exp(-tl * 180))   # 2-3 ms attack: the onset is the sync point
    e = min(n, i0 + L); bell[i0:e] += b[: e - i0] * 0.075 * vel

mix = np.stack([pad[0] + bell * 0.9, pad[1] + bell * 1.1])
rng = np.random.default_rng(7)
ir_len = int(2.8 * SR); tir = np.arange(ir_len) / SR
ir = [rng.standard_normal(ir_len) * np.exp(-tir * 2.2) for _ in range(2)]
wet = np.stack([fftconvolve(mix[k], ir[k])[:n] for k in range(2)])
wet *= np.abs(mix).max() / np.abs(wet).max()
out = mix * 0.6 + wet * 0.4
out = sosfilt(butter(2, 5200, "low", fs=SR, output="sos"), out, axis=1)
out *= np.minimum(1, np.minimum(t / 1.2, (dur - t) / 2.5))
out *= MASTER / np.abs(out[:, : int(8 * BAR * SR)]).max()          # level is set by the body of the piece...
pts = [(b * BAR + bt * BEAT, lv) for b, bt, lv in m["dynamics"]]    # ...then shaped by the dynamics curve
dyn = np.interp(t, [q[0] for q in pts], [q[1] for q in pts])
k = int(0.5 * SR); dyn = np.convolve(dyn, np.ones(k) / k, "same")
out = np.clip(out * dyn, -0.98, 0.98)
pcm = (out.T * 32767).astype("<i2")
w = wave.open(str(root / "public/ambient.wav"), "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
w.writeframes(pcm.tobytes()); w.close()
print(f"ambient.wav written: {dur:.2f}s, {m['bpm']} BPM, {m['bars']} bars")
