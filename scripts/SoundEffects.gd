# scripts/SoundEffects.gd
class_name SoundEffects
extends Object

static func play_sound(tree: SceneTree, type: String) -> void:
	if not tree or not tree.root:
		return
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	tree.root.add_child(player)
	player.stream = create_stream(type)
	player.finished.connect(func(): player.queue_free())
	player.play()

static func create_stream(type: String) -> AudioStreamWAV:
	var sample_rate = 22050
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false

	var duration = 0.3
	var data = PackedByteArray()

	match type:
		"slash":
			duration = 0.22
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = (1.0 - t / duration) * (1.0 - t / duration)
				var freq = lerp(850.0, 180.0, t / duration)
				var noise = (randf() * 2.0 - 1.0) * 0.4
				var s = (sin(t * freq * TAU) * 0.6 + noise) * env * 24000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		"enemy_kill":
			duration = 0.28
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 12.0)
				var freq = lerp(450.0, 90.0, t / duration)
				var s = (sin(t * freq * TAU) + (randf() * 2.0 - 1.0) * 0.6) * env * 28000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		"slow_start":
			duration = 0.45
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = sin(t / duration * PI)
				var freq = lerp(520.0, 140.0, t / duration)
				var s = sin(t * freq * TAU) * env * 26000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		"slow_end":
			duration = 0.35
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = sin(t / duration * PI)
				var freq = lerp(160.0, 480.0, t / duration)
				var s = sin(t * freq * TAU) * env * 22000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		"coin":
			duration = 0.18
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 18.0)
				var f = 1760.0 if t > 0.06 else 1320.0
				var s = sin(t * f * TAU) * env * 20000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		"stumble":
			duration = 0.4
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 8.0)
				var s = (randf() * 2.0 - 1.0) * env * 26000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		"turn":
			duration = 0.2
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = sin(t / duration * PI)
				var s = (randf() * 2.0 - 1.0) * env * 16000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		"ui_hover":
			duration = 0.05
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 35.0)
				var freq = lerp(880.0, 1320.0, t / duration)
				var s = sin(t * freq * TAU) * env * 9000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		"ui_click":
			duration = 0.08
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 28.0)
				var freq = lerp(900.0, 300.0, t / duration)
				var s = sin(t * freq * TAU) * env * 16000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

		_:
			duration = 0.2
			var num_samples = int(duration * sample_rate)
			data.resize(num_samples * 2)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 15.0)
				var s = sin(t * 440.0 * TAU) * env * 18000.0
				var val = clampi(int(s), -32768, 32767)
				data.encode_s16(i * 2, val)

	wav.data = data
	return wav
