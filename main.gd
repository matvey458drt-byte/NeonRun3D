extends Node2D

var light_level: float = 0.0
var on_count: int = 0
var off_count: int = 0
var best_total: int = 0
var anim: Tween
var button_rect: Rect2 = Rect2()
var save_path: String = "user://switch_save.cfg"

func _ready() -> void:
	_load_save()
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = get_viewport_rect().size
	var w: float = s.x
	var h: float = s.y
	var day: Color = Color(0.36, 0.72, 0.96)
	var night: Color = Color(0.012, 0.025, 0.095)
	var sky: Color = night.lerp(day, light_level)
	draw_rect(Rect2(Vector2.ZERO, s), sky)
	# Stars fade as daylight rises.
	for i in range(42):
		var px: float = fmod(float(i * 97 + 31), w)
		var py: float = fmod(float(i * 151 + 63), h * 0.62)
		var alpha: float = (1.0 - light_level) * (0.35 + float(i % 5) * 0.12)
		draw_circle(Vector2(px, py), 1.5 + float(i % 3), Color(1.0, 0.96, 0.75, alpha))
	# Sun / moon
	var orb_color: Color = Color(1.0, 0.91, 0.56).lerp(Color(0.88, 0.92, 1.0), 1.0 - light_level)
	draw_circle(Vector2(w * 0.79, h * 0.17), 48.0, Color(orb_color, 0.15))
	draw_circle(Vector2(w * 0.79, h * 0.17), 31.0, orb_color)
	if light_level < 0.35:
		draw_circle(Vector2(w * 0.805, h * 0.155), 28.0, sky)
	# distant hills
	draw_colored_polygon(PackedVector2Array([Vector2(0,h*0.66),Vector2(w*0.25,h*0.52),Vector2(w*0.48,h*0.67),Vector2(w*0.75,h*0.54),Vector2(w,h*0.65),Vector2(w,h),Vector2(0,h)]), Color(0.055,0.19,0.18).lerp(Color(0.22,0.58,0.32),light_level))
	# Tree trunk and branches
	var cx: float = w * 0.5
	var base: float = h * 0.91
	var bark: Color = Color(0.12,0.065,0.055).lerp(Color(0.30,0.14,0.07),light_level)
	draw_colored_polygon(PackedVector2Array([Vector2(cx-37,base),Vector2(cx-23,h*0.43),Vector2(cx-8,h*0.36),Vector2(cx+17,h*0.42),Vector2(cx+39,base)]),bark)
	draw_line(Vector2(cx-5,h*0.62),Vector2(cx-132,h*0.40),bark,18.0,true)
	draw_line(Vector2(cx+8,h*0.58),Vector2(cx+135,h*0.36),bark,19.0,true)
	draw_line(Vector2(cx-7,h*0.53),Vector2(cx-78,h*0.29),bark,13.0,true)
	draw_line(Vector2(cx+12,h*0.51),Vector2(cx+75,h*0.27),bark,13.0,true)
	# Canopy clusters
	var leaf: Color = Color(0.025,0.17,0.14).lerp(Color(0.10,0.43,0.19),light_level)
	for p in [Vector2(-120,-300),Vector2(-55,-365),Vector2(25,-390),Vector2(105,-325),Vector2(0,-285),Vector2(-165,-245),Vector2(160,-245),Vector2(-85,-220),Vector2(85,-210)]:
		draw_circle(Vector2(cx+p.x, h*0.56+p.y), 92.0, leaf.lightened(0.04 if light_level > 0.5 else 0.0))
	# Counters panel
	var panel: Color = Color(0.015,0.025,0.07,0.82).lerp(Color(0.95,0.97,0.88,0.82),light_level)
	draw_rect(Rect2(w*0.08,h*0.045,w*0.84,145),panel,true,18.0)
	var ink: Color = Color(0.95,0.97,1.0).lerp(Color(0.08,0.16,0.12),light_level)
	draw_string(ThemeDB.fallback_font,Vector2(w*0.5,h*0.095),"ДЕНЬ И НОЧЬ",HORIZONTAL_ALIGNMENT_CENTER,-1,34,ink)
	draw_string(ThemeDB.fallback_font,Vector2(w*0.29,h*0.145),"ВКЛЮЧЕНИЙ: %d" % on_count,HORIZONTAL_ALIGNMENT_CENTER,-1,20,ink)
	draw_string(ThemeDB.fallback_font,Vector2(w*0.71,h*0.145),"ВЫКЛЮЧЕНИЙ: %d" % off_count,HORIZONTAL_ALIGNMENT_CENTER,-1,20,ink)
	draw_string(ThemeDB.fallback_font,Vector2(w*0.5,h*0.175),"ВСЕГО ЩЕЛЧКОВ: %d   •   РЕКОРД: %d" % [on_count+off_count,best_total],HORIZONTAL_ALIGNMENT_CENTER,-1,16,ink)
	# switch plate on the tree
	var bw: float = w*0.42
	var bh: float = 112.0
	button_rect = Rect2(cx-bw*0.5,h*0.69,bw,bh)
	draw_rect(button_rect,Color(0.04,0.045,0.06),true,24.0)
	draw_rect(button_rect.grow(-7),Color(0.16,0.19,0.22),true,19.0)
	var track: Rect2 = Rect2(button_rect.position+Vector2(24,28),Vector2(bw-48,56))
	draw_rect(track,Color(0.035,0.045,0.05),true,28.0)
	var knob_x: float = track.position.x + 28.0 + (track.size.x-56.0)*light_level
	draw_circle(Vector2(knob_x,track.position.y+28),24.0,Color(0.96,0.97,0.92))
	draw_string(ThemeDB.fallback_font,Vector2(cx,h*0.69-18),"НАЖМИ НА ВЫКЛЮЧАТЕЛЬ",HORIZONTAL_ALIGNMENT_CENTER,-1,20,ink)
	var state_text: String = "СВЕТ ВКЛЮЧЁН" if light_level > 0.5 else "СВЕТ ВЫКЛЮЧЕН"
	draw_string(ThemeDB.fallback_font,Vector2(cx,h*0.69+bh+38),state_text,HORIZONTAL_ALIGNMENT_CENTER,-1,24,ink)
	draw_string(ThemeDB.fallback_font,Vector2(cx,h*0.965),"КАСАЙСЯ КНОПКИ • МЕНЯЙ ВРЕМЯ СУТОК",HORIZONTAL_ALIGNMENT_CENTER,-1,15,ink)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if button_rect.has_point(event.position):
			_toggle()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if button_rect.has_point(event.position):
			_toggle()

func _toggle() -> void:
	var turning_on: bool = light_level < 0.5
	if turning_on:
		on_count += 1
	else:
		off_count += 1
	best_total = max(best_total,on_count+off_count)
	_save()
	if anim and anim.is_running():
		anim.kill()
	anim = create_tween()
	anim.set_trans(Tween.TRANS_SINE)
	anim.set_ease(Tween.EASE_IN_OUT)
	anim.tween_property(self,"light_level",1.0 if turning_on else 0.0,0.85)
	anim.tween_callback(queue_redraw)
	queue_redraw()

func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("stats","on",on_count)
	cfg.set_value("stats","off",off_count)
	cfg.set_value("stats","best",best_total)
	cfg.save(save_path)

func _load_save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(save_path) == OK:
		on_count = int(cfg.get_value("stats","on",0))
		off_count = int(cfg.get_value("stats","off",0))
		best_total = int(cfg.get_value("stats","best",0))
		light_level = 1.0 if on_count > off_count else 0.0
