extends Control
## Allele-frequency panel: pick a gene, see each allele's share (0-1) over time,
## the current genotype counts, and how many births came from each source.

const MAX_SAMPLES: int = 600
const FONT_SIZE: int = 13
const SMALL_FONT_SIZE: int = 11
const PLOT_RECT: Rect2 = Rect2(34.0, 70.0, 154.0, 160.0)

var _locus_option: OptionButton
var _font: Font
var _locus_ids: Array[String] = []
var _selected_locus: String = ""
# locus id -> {allele -> Array[float]}
var _history: Dictionary = {}
var _samples: int = 0
var _genotypes: Array[Dictionary] = []
var _births: Dictionary = {"mating": 0, "self": 0, "clone": 0}
var _deaths: Dictionary = {"starved": 0, "eaten": 0, "hawk": 0}


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locus_ids = EvoGenetics.LOCUS_IDS.duplicate()
	_selected_locus = _locus_ids[0]
	for id: String in _locus_ids:
		var per_allele: Dictionary = {}
		for allele: String in EvoGenetics.get_library().get_locus(id).alleles:
			var series: Array[float] = []
			per_allele[allele] = series
		_history[id] = per_allele
	_locus_option = OptionButton.new()
	for i: int in range(_locus_ids.size()):
		_locus_option.add_item(EvoGenetics.locus_name(_locus_ids[i]), i)
	_locus_option.position = Vector2(8.0, 30.0)
	_locus_option.size = Vector2(maxf(size.x, 200.0) - 16.0, 28.0)
	_locus_option.item_selected.connect(_on_locus_selected)
	add_child(_locus_option)


func _on_locus_selected(index: int) -> void:
	_selected_locus = _locus_ids[_locus_option.get_item_id(index)]
	queue_redraw()


## Record one frequency sample for every locus (called on the population graph's interval).
func sample(genotypes: Array[Dictionary]) -> void:
	_genotypes = genotypes
	for id: String in _locus_ids:
		var freqs: Dictionary = EvoGenetics.allele_frequencies(genotypes, id)
		var per_allele: Dictionary = _history[id]
		for allele: String in per_allele.keys():
			var series: Array[float] = per_allele[allele]
			series.append(float(freqs.get(allele, 0.0)))
			if series.size() > MAX_SAMPLES:
				series.pop_front()
	_samples = mini(_samples + 1, MAX_SAMPLES)
	queue_redraw()


func set_births(births: Dictionary) -> void:
	_births = births
	queue_redraw()


func set_deaths(deaths: Dictionary) -> void:
	_deaths = deaths
	queue_redraw()


func _allele_color(locus_id: String, allele: String) -> Color:
	match allele:
		"Cb":
			return Color(0.72, 0.45, 0.22)
		"Cg":
			return Color(0.3, 0.85, 0.3)
		"Cy":
			return Color(0.75, 0.75, 0.8)
	var alleles: Array[String] = EvoGenetics.get_library().get_locus(locus_id).alleles
	if alleles.find(allele) == 0:
		return Color(1.0, 0.6, 0.2)
	return Color(0.35, 0.7, 1.0)


func _text(pos: Vector2, text: String, font_size: int = FONT_SIZE, color: Color = Color.WHITE) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw() -> void:
	if _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.1, 0.85))
	_text(Vector2(8.0, 20.0), "Allele frequencies", 15)

	# Plot area with 0 / 0.5 / 1 gridlines
	draw_rect(PLOT_RECT, Color(0.3, 0.3, 0.3, 0.25), false, 2.0)
	for i: int in range(3):
		var ratio: float = float(i) / 2.0
		var y: float = PLOT_RECT.position.y + PLOT_RECT.size.y * (1.0 - ratio)
		draw_line(Vector2(PLOT_RECT.position.x, y), Vector2(PLOT_RECT.end.x, y), Color(0.8, 0.8, 0.8, 0.5), 1.0)
		_text(Vector2(6.0, y + 4.0), "%.1f" % ratio, SMALL_FONT_SIZE)
	_text(Vector2(PLOT_RECT.position.x, PLOT_RECT.end.y + 14.0), "time  ->", SMALL_FONT_SIZE, Color(0.8, 0.8, 0.8))

	var locus: GenomeLocus = EvoGenetics.get_library().get_locus(_selected_locus)
	var per_allele: Dictionary = _history[_selected_locus]
	var freqs: Dictionary = EvoGenetics.allele_frequencies(_genotypes, _selected_locus)

	# One line per allele
	for allele: String in locus.alleles:
		var series: Array[float] = per_allele[allele]
		if series.size() >= 2:
			var points: PackedVector2Array = PackedVector2Array()
			var step_x: float = PLOT_RECT.size.x / float(series.size() - 1)
			for i: int in range(series.size()):
				var x: float = PLOT_RECT.position.x + step_x * float(i)
				var y: float = PLOT_RECT.position.y + PLOT_RECT.size.y * (1.0 - clampf(series[i], 0.0, 1.0))
				points.append(Vector2(x, y))
			draw_polyline(points, _allele_color(_selected_locus, allele), 2.0, true)

	# Legend with current share
	var ly: float = PLOT_RECT.end.y + 34.0
	for allele: String in locus.alleles:
		var col: Color = _allele_color(_selected_locus, allele)
		draw_rect(Rect2(10.0, ly - 9.0, 10.0, 10.0), col)
		var pct: int = int(round(float(freqs.get(allele, 0.0)) * 100.0))
		_text(Vector2(26.0, ly), "%s  %d%%" % [allele, pct])
		ly += 17.0

	# Current genotype counts, e.g. "SS 12 · Ss 20 · ss 5"
	ly += 8.0
	_text(Vector2(8.0, ly), "Genotypes now", FONT_SIZE, Color(0.8, 0.8, 0.8))
	var counts: Dictionary = EvoGenetics.genotype_counts(_genotypes, _selected_locus)
	var parts: PackedStringArray = PackedStringArray()
	for key: String in counts.keys():
		parts.append("%s %d" % [key, int(counts[key])])
	var count_text: String = "  ".join(parts)
	draw_multiline_string(_font, Vector2(8.0, ly + 17.0), count_text, HORIZONTAL_ALIGNMENT_LEFT,
			maxf(size.x, 200.0) - 16.0, FONT_SIZE, -1, Color.WHITE)

	# Births by source
	var by: float = ly + 17.0 + 60.0
	_text(Vector2(8.0, by), "Births so far", FONT_SIZE, Color(0.8, 0.8, 0.8))
	_text(Vector2(8.0, by + 17.0), "Matings: %d" % int(_births.get("mating", 0)))
	_text(Vector2(8.0, by + 34.0), "Self-fertilized: %d" % int(_births.get("self", 0)))
	_text(Vector2(8.0, by + 51.0), "Clones: %d" % int(_births.get("clone", 0)))

	# Deaths by cause
	_text(Vector2(8.0, by + 76.0), "Deaths so far", FONT_SIZE, Color(0.8, 0.8, 0.8))
	_text(Vector2(8.0, by + 93.0), "Starved: %d" % int(_deaths.get("starved", 0)))
	_text(Vector2(8.0, by + 110.0), "Eaten by cannibals: %d" % int(_deaths.get("eaten", 0)))
	_text(Vector2(8.0, by + 127.0), "Hawks: %d" % int(_deaths.get("hawk", 0)))
