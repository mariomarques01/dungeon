extends RefCounted
# Recorded, element-specific sound events and a licensed orchestral dungeon score.
const ROUTES = {"sword":"steel","blade":"steel","fire":"fire","shield":"shield","ice":"ice","lightning":"lightning","storm":"storm","earth":"earth","water":"water","heal":"heal","spark":"shield","steel":"steel","arcane":"charge","nature":"heal","dark":"storm","bite":"hurt"}
var game
var streams: Dictionary = {}
var music: AudioStreamPlayer
var voices: Array = []
var history: Array = []
var enabled = true
var duck = 0.0
var music_level = -14.0

func _init(owner) -> void:
 game=owner
 if AudioServer.get_bus_effect_count(0)==0:
  var limiter=AudioEffectLimiter.new()
  limiter.ceiling_db=-1.0
  limiter.threshold_db=-1.0
  AudioServer.add_bus_effect(0,limiter)
 for kind in ["steel","fire","ice","lightning","water","earth","storm","charge","shield","heal","hurt","armor","freeze","ui"]:
  streams[kind]=load("res://assets/v2/audio/"+kind+".ogg")
 music=AudioStreamPlayer.new()
 music.stream=load("res://assets/v2/audio/dungeon-score.ogg")
 music.stream.loop=true
 music.volume_db=music_level
 game.add_child(music)

func update(delta: float) -> void:
 duck=maxf(0,duck-delta)
 if is_instance_valid(music): music.volume_db=lerpf(music.volume_db,music_level-(5.0 if duck>0 else 0.0),minf(1,delta*7))

func set_enabled(value: bool) -> void:
 enabled=value
 if not value:
  music.stream_paused=true
  for voice in voices:
   if is_instance_valid(voice): voice.stop(); voice.queue_free()
  voices.clear()
 elif game.screen=="battle" and not game.done: start_music()

func start_music() -> void:
 if not enabled: return
 music.stream_paused=false
 if not music.playing: music.play()
 music_level=-14.0

func finish_music() -> void:
 music_level=-25.0

func stop_music() -> void:
 music.stop()

func clip_for(art: String) -> String:
 return ROUTES.get(art,"steel")

func play(kind: String, volume = -3.0, pitch = 1.0) -> void:
 if not enabled or not streams.has(kind): return
 var voice=AudioStreamPlayer.new()
 voice.stream=streams[kind]
 voice.volume_db=volume
 voice.pitch_scale=pitch
 game.add_child(voice)
 voices.append(voice)
 if voices.size()>10:
  var oldest=voices.pop_front()
  if is_instance_valid(oldest): oldest.stop(); oldest.queue_free()
 voice.finished.connect(func(): voices.erase(voice); voice.queue_free())
 voice.play()
 history.append({"kind":kind,"tick":Time.get_ticks_msec()})
 if history.size()>64: history.pop_front()
 if kind!="ui": duck=0.75

func charge(art: String) -> void:
 play("charge",-13.0,0.96 if art=="earth" else 1.0)

func impact(art: String, damage: int, blocked: int, target_enemy: bool) -> void:
 var kind=clip_for(art)
 play(kind,-2.0)
 if art=="storm": play("lightning",-6.0)
 if blocked>0: play("shield",-5.0)
 if damage>0: play("hurt" if target_enemy else "armor",-13.0)
