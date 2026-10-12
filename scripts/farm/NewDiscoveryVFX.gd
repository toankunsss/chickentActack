class_name NewDiscoveryVFX
extends Sprite2D
## Eight-frame first-discovery halo generated for the chicken collection.

const FRAME_COUNT := 8
const FPS := 7.0
const FRAME_ROOT := "res://assets/effects/new-discovery"

var elapsed := 0.0
var frames: Array[Texture2D] = []

func _ready() -> void:
	for index in FRAME_COUNT:
		frames.append(load("%s/frame-%02d.png" % [FRAME_ROOT, index]) as Texture2D)
	texture = frames[0]
	centered = true
	z_index = 950

func _process(delta: float) -> void:
	elapsed += delta
	var frame := mini(FRAME_COUNT - 1, int(elapsed * FPS))
	texture = frames[frame]
	if elapsed >= 1.35:
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.28)
		fade.tween_callback(queue_free)
		set_process(false)
