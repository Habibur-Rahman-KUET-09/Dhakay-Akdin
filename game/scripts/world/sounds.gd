## Street sounds made in code (no recordings yet): Rahim Chacha's bell, the
## horns of CNGs and buses, and the steady hum of a busy road.
extends RefCounted

const RATE := 22050


static func _stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## The rickshaw bell: two quick metallic strikes, "kring-kring".
static func bell() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[2093.0, 0.5], [2817.0, 0.3], [4186.0, 0.18], [5590.0, 0.1]]
	for strike in [0.0, 0.28]:
		var start := int(strike * RATE)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var env := exp(-t * 7.0) * (1.0 + 0.35 * sin(TAU * 32.0 * t))
			var v := 0.0
			for pt in partials:
				v += sin(TAU * pt[0] * t) * pt[1]
			out[i] += v * env * 0.45
	return _stream(out)


## A horn: two buzzy tones together, slightly wobbling.
static func horn(f1: float, f2: float, seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.015) * minf(1.0, (seconds - t) / 0.05)
		var wob := 1.0 + 0.004 * sin(TAU * 6.0 * t)
		var v := 0.0
		for f in [f1, f2]:
			for k in [1, 3, 5]:
				v += sin(TAU * f * wob * k * t) / k
		out[i] = v * env * 0.22
	return _stream(out)


## The road's hum: rumbling low noise, looped (4 s).
static func street_hum() -> AudioStreamWAV:
	var n := RATE * 4
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var brown := 0.0
	var low := 0.0
	for i in n:
		brown = clampf(brown + rng.randf_range(-0.02, 0.02), -1.0, 1.0)
		low += (brown - low) * 0.05
		var t := float(i) / RATE
		out[i] = low * 0.9 + sin(TAU * 55.0 * t) * 0.03 * (0.6 + 0.4 * sin(TAU * 0.5 * t))
	# Fade the seam so the loop does not click.
	var fade := RATE / 10
	for i in fade:
		var k := float(i) / fade
		out[i] *= k
		out[n - 1 - i] *= k
	return _stream(out, true)
