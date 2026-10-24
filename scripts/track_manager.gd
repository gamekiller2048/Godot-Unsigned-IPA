extends Node3D
class_name NeonRunnerTrackManager

const SEGMENT_SCENE: PackedScene = preload("res://scenes/track_segment.tscn")
const SEGMENT_LENGTH := 36.0
const SEGMENTS_AHEAD := 5

var segments: Array[NeonRunnerTrackSegment] = []
var next_segment_z := 0.0
var next_seed := 1

func reset_track() -> void:
	for segment in segments:
		segment.queue_free()
	segments.clear()
	next_segment_z = 0.0
	next_seed = 1
	for index in range(SEGMENTS_AHEAD):
		_add_segment()

func update_for_player(player_z: float) -> void:
	while next_segment_z > player_z - SEGMENT_LENGTH * SEGMENTS_AHEAD:
		_add_segment()
	# Streckenstücke hinter dem Spieler freigeben, damit der Endloslauf begrenzt bleibt.
	for segment in segments.duplicate():
		if segment.position.z > player_z + SEGMENT_LENGTH * 1.25:
			segments.erase(segment)
			segment.queue_free()

func _add_segment() -> void:
	var segment := SEGMENT_SCENE.instantiate() as NeonRunnerTrackSegment
	segment.segment_seed = next_seed
	segment.position.z = next_segment_z
	add_child(segment)
	segments.append(segment)
	next_segment_z -= SEGMENT_LENGTH
	next_seed += 1
