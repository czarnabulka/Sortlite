extends SceneTree
## Makes the game's sound effects (assets/sounds/synth/*.wav): one soft
## chiptune family, tuned to C major. Every sound is a list of voices
## (pulse / triangle / sine / noise) with a pitch glide, an attack, an
## exponential decay and a low-pass. The 8-bit jingles stay Kenney files.
##
##   godot --headless --path . -s res://tools/make_sfx.gd [-- <out_dir>]
##   godot --headless --path . --import
##
## Prints each file's RMS and the volume row that puts it at its target
## loudness; copy the row into Sfx.SOUNDS and the RMS into tests/test_sfx.gd.
## Output is deterministic (fixed noise seed).

const SR := 44100

# Played loudness targets (file RMS + row dB), as in ui/sfx.gd.
const OFTEN := -30.0
const EVENT := -27.0
const BIG := -24.5


static func m(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


## One voice. f0/f1 in Hz (glide, exponential), d = seconds, a = attack,
## tau = decay time constant, lp = low-pass Hz, duty for pulse, vib = [rate, depth].
static func v(t: float, d: float, w: String, f0: float, f1 := -1.0, amp := 1.0, tau := 0.08, lp := 5000.0, duty := 0.25, a := 0.003, vib := [0.0, 0.0]) -> Dictionary:
	return {t = t, d = d, w = w, f0 = f0, f1 = (f0 if f1 < 0.0 else f1), amp = amp, tau = tau, lp = lp, duty = duty, a = a, vib = vib}


## Notes in a row: midi list, each `step` long, the last one rings `last` s.
static func arp(t: float, notes: Array, step: float, last: float, w := "pulse", amp := 0.6, duty := 0.25, lp := 4500.0, tau_last := 0.15, vib := [0.0, 0.0]) -> Array:
	var out := []
	for i in notes.size():
		var is_last := i == notes.size() - 1
		var d := last if is_last else step
		out.append(v(t + i * step, d, w, m(notes[i]), -1.0, amp, tau_last if is_last else step * 0.9, lp, duty, 0.003, vib if is_last else [0.0, 0.0]))
	return out


func sounds() -> Dictionary:
	return {
		# --- Menus and cards: short, light, high ---
		"cursor": [OFTEN, [v(0, 0.03, "pulse", m(88), -1, 0.5, 0.012, 6000, 0.125), v(0, 0.03, "tri", m(76), -1, 0.5, 0.015)]],
		"confirm": [EVENT, arp(0, [79, 84], 0.05, 0.11, "pulse", 0.55, 0.25, 5000, 0.05) + arp(0, [67, 72], 0.05, 0.11, "tri", 0.5, 0.5, 5000, 0.06)],
		"back": [EVENT, arp(0, [79, 72], 0.045, 0.09, "pulse", 0.5, 0.25, 4000, 0.04) + arp(0, [67, 60], 0.045, 0.09, "tri", 0.5, 0.5, 4000, 0.05)],
		"toggle": [EVENT, [v(0, 0.05, "pulse", m(81), -1, 0.6, 0.018, 5000, 0.5), v(0, 0.05, "tri", m(69), -1, 0.4, 0.02)]],
		"card_open": [EVENT, [v(0, 0.14, "pulse", m(72), m(84), 0.45, 0.07, 4500, 0.125), v(0, 0.14, "tri", m(60), m(72), 0.5, 0.08), v(0, 0.08, "noise", 6000, 12000, 0.12, 0.03, 7000)]],
		"card_close": [EVENT, [v(0, 0.12, "pulse", m(84), m(72), 0.45, 0.05, 4500, 0.125), v(0, 0.12, "tri", m(72), m(60), 0.5, 0.06), v(0, 0.07, "noise", 12000, 6000, 0.12, 0.025, 7000)]],
		# --- Moves: short, mellow, the same family ---
		# Swap: two neighbours trade places, "bip-bop".
		"swap": [OFTEN, [v(0, 0.035, "pulse", m(79), -1, 0.5, 0.02, 3200, 0.25), v(0.032, 0.05, "pulse", m(74), -1, 0.5, 0.025, 3200, 0.25), v(0, 0.08, "tri", m(55), -1, 0.5, 0.03)]],
		# Insert: the key slides down into place and settles, "zip-tock".
		"insert": [OFTEN, [v(0, 0.08, "pulse", m(84), m(72), 0.35, 0.06, 3500, 0.125), v(0.075, 0.07, "tri", m(60), m(55), 0.8, 0.03), v(0.075, 0.02, "noise", 3000, -1, 0.15, 0.008, 3000)]],
		# Flip: a quick swish up and a pop as the stack lands.
		"flip": [OFTEN, [v(0, 0.09, "noise", 3000, 12000, 0.35, 0.05, 5000), v(0, 0.09, "tri", m(60), m(72), 0.5, 0.06), v(0.085, 0.06, "pulse", m(76), -1, 0.4, 0.025, 4000, 0.25), v(0.085, 0.06, "tri", m(64), -1, 0.5, 0.03)]],
		# Partition: the segment splits, one voice up and one down.
		"partition": [OFTEN, [v(0, 0.13, "pulse", m(76), m(88), 0.35, 0.06, 4000, 0.25), v(0, 0.13, "pulse", m(76), m(64), 0.35, 0.06, 4000, 0.125), v(0, 0.02, "noise", 5000, -1, 0.25, 0.008, 5000)]],
		# Merge: two runs close into one, a voice from each side meeting.
		"merge": [OFTEN, [v(0, 0.12, "pulse", m(84), m(76), 0.35, 0.06, 4000, 0.25), v(0, 0.12, "pulse", m(64), m(76), 0.35, 0.06, 4000, 0.125), v(0.115, 0.05, "tri", m(76), -1, 0.6, 0.025)]],
		# Pop: the root jumps to the top of the column, a quick upward blip.
		"pop": [OFTEN, [v(0, 0.06, "pulse", m(67), m(79), 0.4, 0.04, 4000, 0.25), v(0.055, 0.07, "tri", m(84), -1, 0.6, 0.03), v(0, 0.02, "noise", 6000, -1, 0.15, 0.008, 6000)]],
		# Wrong: a low buzzy "nuh-uh".
		"wrong": [EVENT, [v(0, 0.07, "pulse", m(57), -1, 0.5, 0.2, 1800, 0.5), v(0.08, 0.12, "pulse", m(53), -1, 0.5, 0.08, 1800, 0.5)]],
		# Arrive: a number drops in, a soft plop.
		"arrive": [OFTEN, [v(0, 0.07, "tri", m(79), m(67), 0.8, 0.03), v(0, 0.03, "pulse", m(79), m(72), 0.2, 0.012, 3000, 0.125)]],
		# Ship: the hand leaves, a quick rising sweep and arpeggio.
		"ship": [EVENT, arp(0, [72, 76, 79, 84], 0.028, 0.09, "pulse", 0.45, 0.25, 4500, 0.05) + [v(0, 0.12, "noise", 2000, 9000, 0.18, 0.06, 6000)]],
		# --- Scoring: notes of C major; the game steps them up the pentatonic ---
		"score": [OFTEN, [v(0, 0.2, "pulse", m(72), -1, 0.35, 0.07, 4000, 0.125), v(0, 0.2, "tri", m(72), -1, 0.7, 0.09), v(0, 0.2, "sin", m(84), -1, 0.15, 0.05)]],
		# Chips: an unpitched coin tink under the notes from the 4th on.
		"chips": [OFTEN, [v(0, 0.03, "noise", 14000, -1, 0.5, 0.012, 9000), v(0, 0.06, "pulse", 2637, -1, 0.15, 0.02, 7000, 0.5), v(0, 0.06, "pulse", 3520, -1, 0.1, 0.018, 7000, 0.5)]],
		"combo_small": [EVENT, arp(0, [84, 88, 91], 0.045, 0.16, "pulse", 0.4, 0.25, 4500, 0.08) + arp(0, [72, 76, 79], 0.045, 0.16, "tri", 0.5, 0.5, 4500, 0.1)],
		"combo_mid": [EVENT, arp(0, [84, 88, 91, 96], 0.045, 0.24, "pulse", 0.4, 0.25, 4500, 0.12, [6.0, 0.006]) + arp(0, [72, 76, 79, 84], 0.045, 0.24, "tri", 0.5, 0.5, 4500, 0.14)],
		"combo_big": [BIG, arp(0, [72, 76, 79, 84, 88, 91], 0.045, 0.06, "pulse", 0.35, 0.25, 4500, 0.05) + [v(0.27, 0.4, "pulse", m(84), -1, 0.3, 0.2, 4500, 0.25, 0.003, [6.0, 0.006]), v(0.27, 0.4, "pulse", m(88), -1, 0.25, 0.2, 4500, 0.125, 0.003, [6.0, 0.006]), v(0.27, 0.4, "tri", m(67), -1, 0.6, 0.25), v(0.27, 0.4, "tri", m(55), -1, 0.4, 0.25)]],
		# Item: an item kicks in, a small sparkle.
		"item": [OFTEN, arp(0, [88, 93], 0.03, 0.08, "pulse", 0.35, 0.125, 5500, 0.035) + arp(0, [76, 81], 0.03, 0.08, "tri", 0.4, 0.5, 5500, 0.04)],
		# Pattern: a pattern lights up, a short power-up sweep.
		"pattern": [EVENT, [v(0, 0.22, "pulse", m(72), m(84), 0.35, 0.15, 4000, 0.25, 0.003, [14.0, 0.012]), v(0, 0.22, "tri", m(79), m(91), 0.4, 0.15)]],
		# Ready: a number joins the ready run, a soft low note (pitched up by the game).
		"ready": [OFTEN, [v(0, 0.08, "tri", m(67), -1, 0.8, 0.035), v(0, 0.03, "pulse", m(67), -1, 0.2, 0.01, 2500, 0.125)]],
		# Overflow: a life lost, a crunch falling down.
		"overflow": [EVENT, [v(0, 0.12, "noise", 3000, 800, 0.6, 0.06, 3000), v(0, 0.28, "pulse", m(57), m(40), 0.5, 0.12, 1500, 0.5), v(0, 0.28, "tri", m(45), m(33), 0.6, 0.14)]],
		# --- Boss: lower, darker, same family ---
		"boss_intro": [BIG, arp(0, [50, 49, 45], 0.2, 0.5, "pulse", 0.45, 0.5, 1400, 0.3, [5.0, 0.01]) + arp(0, [38, 37, 33], 0.2, 0.5, "tri", 0.7, 0.5, 2000, 0.35)],
		"boss_aim": [EVENT, [v(0, 0.05, "pulse", m(81), -1, 0.45, 0.04, 3500, 0.5), v(0.09, 0.05, "pulse", m(81), -1, 0.45, 0.04, 3500, 0.5)]],
		"boss_strike": [BIG, [v(0, 0.1, "noise", 4000, 600, 0.7, 0.05, 2500), v(0, 0.3, "pulse", 220, 45, 0.6, 0.12, 1200, 0.5), v(0, 0.3, "tri", 110, 35, 0.8, 0.15)]],
		"boss_dodged": [EVENT, [v(0, 0.1, "noise", 2000, 10000, 0.3, 0.06, 6000), v(0, 0.12, "tri", m(64), m(76), 0.5, 0.08)] + arp(0.1, [79, 84], 0.04, 0.1, "pulse", 0.35, 0.25, 4500, 0.05)],
		"boss_enraged": [BIG, [v(0, 0.65, "pulse", m(57), m(42), 0.45, 0.4, 1300, 0.5, 0.01, [9.0, 0.03]), v(0, 0.65, "tri", m(45), m(30), 0.7, 0.45), v(0, 0.2, "noise", 1500, 500, 0.25, 0.1, 1500)]],
		# Shield: a metal plink with a short ring.
		"shield": [EVENT, [v(0, 0.02, "noise", 9000, -1, 0.35, 0.008, 8000), v(0, 0.3, "pulse", 1175, -1, 0.3, 0.1, 5000, 0.5), v(0, 0.3, "pulse", 1661, -1, 0.2, 0.08, 5000, 0.5), v(0, 0.3, "sin", 587, -1, 0.4, 0.12)]],
		# --- Between rooms ---
		# Deal: three cards swish in.
		"deal": [EVENT, [v(0, 0.05, "noise", 6000, 11000, 0.5, 0.025, 6000), v(0.07, 0.05, "noise", 6000, 11000, 0.45, 0.025, 6000), v(0.14, 0.05, "noise", 6000, 11000, 0.4, 0.025, 6000)] + arp(0, [72, 76, 79], 0.07, 0.07, "tri", 0.35, 0.5, 4000, 0.03)],
		"card_hover": [OFTEN, [v(0, 0.035, "tri", m(76), -1, 0.7, 0.015), v(0, 0.02, "noise", 9000, -1, 0.15, 0.006, 7000)]],
		"take": [EVENT, arp(0, [72, 79, 84], 0.045, 0.16, "pulse", 0.45, 0.25, 4500, 0.08) + arp(0, [60, 67, 72], 0.045, 0.16, "tri", 0.5, 0.5, 4500, 0.1)],
		"skip": [EVENT, [v(0, 0.07, "noise", 10000, 4000, 0.3, 0.04, 6000)] + arp(0.02, [76, 72], 0.05, 0.09, "tri", 0.6, 0.5, 4000, 0.05)],
		"heal": [EVENT, arp(0, [72, 76, 79, 84], 0.07, 0.25, "pulse", 0.35, 0.125, 4000, 0.12, [7.0, 0.008]) + arp(0, [60, 64, 67, 72], 0.07, 0.25, "tri", 0.55, 0.5, 4000, 0.14)],
	}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "res://assets/sounds/synth"
	DirAccess.make_dir_recursive_absolute(out)
	var all := sounds()
	print("name\tdur_s\trms_db\trow_db\ttarget")
	for name: String in all:
		var target: float = all[name][0]
		var buf := render(all[name][1])
		var rms := 0.0
		for s in buf:
			rms += s * s
		rms = linear_to_db(sqrt(rms / buf.size()))
		save(buf, out.path_join(name + ".wav"))
		print("%s\t%.2f\t%.1f\t%.1f\t%.1f" % [name, buf.size() / float(SR), rms, target - rms, target])
	quit()


func render(voices: Array) -> PackedFloat32Array:
	var end := 0.0
	for vo: Dictionary in voices:
		end = maxf(end, vo.t + vo.d)
	var n := int((end + 0.01) * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for vo: Dictionary in voices:
		var start := int(vo.t * SR)
		var len := int(vo.d * SR)
		var phase := 0.0
		var hold := 0.0
		var lp1 := 0.0
		var lp2 := 0.0
		var k := 1.0 - exp(-TAU * minf(vo.lp, SR * 0.45) / SR)
		var fade := int(0.004 * SR)
		for i in len:
			var t := i / float(SR)
			var f: float = vo.f0 * pow(vo.f1 / vo.f0, t / vo.d)
			if vo.vib[1] > 0.0:
				f *= 1.0 + vo.vib[1] * sin(TAU * vo.vib[0] * t)
			var dt := f / SR
			var x := 0.0
			match vo.w:
				"pulse":
					x = (1.0 if phase < vo.duty else -1.0) + _blep(phase, dt) - _blep(fposmod(phase + 1.0 - vo.duty, 1.0), dt)
				"tri":
					x = 4.0 * absf(phase - 0.5) - 1.0
				"sin":
					x = sin(TAU * phase)
				"noise":
					x = hold
			phase += dt
			if phase >= 1.0:
				phase -= 1.0
				hold = rng.randf_range(-1.0, 1.0)
			lp1 += k * (x - lp1)
			lp2 += k * (lp1 - lp2)
			var env := 1.0
			if t < vo.a:
				env = t / vo.a
			else:
				env = exp(-(t - vo.a) / vo.tau)
			if i > len - fade:
				env *= (len - i) / float(fade)
			var j := start + i
			if j < n:
				buf[j] += lp2 * env * vo.amp
	# Normalize the peak to -1 dBFS.
	var peak := 0.0
	for s in buf:
		peak = maxf(peak, absf(s))
	var g := db_to_linear(-1.0) / maxf(peak, 1e-6)
	for i in n:
		buf[i] *= g
	return buf


static func _blep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


func save(buf: PackedFloat32Array, path: String) -> void:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	w.save_to_wav(path)
