extends Control
## Presentation only: normalized polyline and distances read from snapshots.
var points: PackedVector2Array = []
var lengths: PackedFloat32Array = []
var total: float = 0.0
var rows: Array = []
var colors: Dictionary = {}
var selected_id: int = -1
func configure(raw: Array, team_colors: Dictionary) -> void:
	points.clear(); lengths.clear(); total = 0.0; colors = team_colors.duplicate()
	for p in raw:
		if p is Array and p.size() == 2:
			var v := Vector2(float(p[0]), float(p[1]))
			if points.is_empty() or v != points[-1]: points.append(v)
	if points.size() < 2: return
	for i in range(points.size()):
		lengths.append(total)
		total += points[i].distance_to(points[(i+1)%points.size()])
	queue_redraw()
func update_rows(data: Array, id: int) -> void:
	rows = data; selected_id = id; queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("11161c"))
	if points.size() < 2 or total <= 0.0: return
	var lo: Vector2 = points[0]; var hi: Vector2 = points[0]
	for p in points: lo = lo.min(p); hi = hi.max(p)
	var extent: Vector2 = hi-lo
	var scale_value: float = minf((size.x-60)/maxf(extent.x,0.01),(size.y-60)/maxf(extent.y,0.01))
	if scale_value <= 0: return
	var offset: Vector2 = (size-extent*scale_value)/2-lo*scale_value
	var screen_points: PackedVector2Array = []
	for p in points: screen_points.append(p*scale_value+offset)
	screen_points.append(screen_points[0])
	draw_polyline(screen_points,Color("303b45"),16.0,true)
	draw_polyline(screen_points,Color("9aa4ae"),2.0,true)
	draw_circle(screen_points[0],7,Color.WHITE)
	for row in rows:
		var target: float = fposmod(float(row.progress)/1000000.0,1.0)*total
		var idx: int = 0
		while idx+1 < lengths.size() and lengths[idx+1] <= target: idx += 1
		var end: int = (idx+1)%points.size()
		var segment: float = points[idx].distance_to(points[end])
		var v: Vector2 = screen_points[idx].lerp(screen_points[end],clampf((target-lengths[idx])/maxf(0.00001,segment),0.0,1.0))
		var color: Color = Color(str(colors.get(row.team,"#b1b8c2")))
		if bool(row.retired): color = Color("686868")
		draw_circle(v,7,color)
		if int(row.id) == selected_id: draw_arc(v,11,0,TAU,24,Color("ff8126"),3,true)
