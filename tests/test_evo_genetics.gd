extends SceneTree
## EvoGenetics: genotype -> genome mappings, founders, crosses, clones, allele-frequency helpers.

var _passed: int = 0
var _failed: int = 0
var _lib: GenomeLibrary


func _init() -> void:
	_lib = EvoGenetics.get_library()
	_run()
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _run() -> void:
	_test_mappings()
	_test_genome_shape()
	_test_founders()
	_test_crosses()
	_test_clone_and_mutation()
	_test_allele_helpers()


func _expr(locus: String, a: String, b: Variant) -> Variant:
	var genome: Dictionary = EvoGenetics.to_genome({locus: [a, b]})
	return genome[locus]


func _test_mappings() -> void:
	# Incomplete dominance loci, both allele orders
	var tables: Dictionary = {
		"metabolism": ["M", "m", "high", "medium", "low"],
		"speed": ["S", "s", "fast", "medium", "slow"],
		"growth_rate": ["G", "g", "fast", "normal", "slow"],
	}
	for locus: String in tables.keys():
		var t: Array = tables[locus]
		var big: String = t[0]
		var small: String = t[1]
		_check(_expr(locus, big, big) == t[2], locus + " homozygous big")
		_check(_expr(locus, big, small) == t[3], locus + " het (big,small)")
		_check(_expr(locus, small, big) == t[3], locus + " het (small,big)")
		_check(_expr(locus, small, small) == t[4], locus + " homozygous small")
	# Color hierarchy Cb > Cg > Cy: all 9 ordered pairs
	var expect_color: Dictionary = {
		"CbCb": "brown", "CbCg": "brown", "CbCy": "brown",
		"CgCb": "brown", "CgCg": "green", "CgCy": "green",
		"CyCb": "brown", "CyCg": "green", "CyCy": "gray",
	}
	for key: String in expect_color.keys():
		var a: String = key.substr(0, 2)
		var b: String = key.substr(2, 2)
		_check(_expr("color", a, b) == expect_color[key], "color " + key)
	# Cannibal: only kk
	_check(_expr("cannibal", "K", "K") == false, "KK not cannibal")
	_check(_expr("cannibal", "K", "k") == false, "Kk not cannibal")
	_check(_expr("cannibal", "k", "K") == false, "kK not cannibal")
	_check(_expr("cannibal", "k", "k") == true, "kk cannibal")


func _test_genome_shape() -> void:
	var g: Dictionary = EvoGenetics.to_genome(EvoGenetics.random_founder(_rng(3)))
	var keys: Array = g.keys()
	keys.sort()
	_check(keys == ["cannibal", "color", "growth_rate", "metabolism", "speed"], "genome keys unchanged")
	_check(g["cannibal"] is bool, "cannibal is bool")
	_check(["low", "medium", "high"].has(g["metabolism"]), "metabolism value set")
	_check(["slow", "medium", "fast"].has(g["speed"]), "speed value set")
	_check(["slow", "normal", "fast"].has(g["growth_rate"]), "growth_rate value set")
	_check(["green", "brown", "gray"].has(g["color"]), "color value set")


func _test_founders() -> void:
	var rng: RandomNumberGenerator = _rng(11)
	var n: int = 10000
	var cannibals: int = 0
	var colors: Dictionary = {"green": 0, "brown": 0, "gray": 0}
	var met: Dictionary = {"high": 0, "medium": 0, "low": 0}
	for i: int in range(n):
		var g: Dictionary = EvoGenetics.to_genome(EvoGenetics.random_founder(rng))
		if g["cannibal"]:
			cannibals += 1
		colors[g["color"]] = int(colors[g["color"]]) + 1
		met[g["metabolism"]] = int(met[g["metabolism"]]) + 1
	var rate: float = float(cannibals) / float(n)
	_check(absf(rate - EvoGenetics.FOUNDER_CANNIBAL_PROBABILITY) < 0.02, "founder cannibal rate ~0.2 (got %.4f)" % rate)
	for c: String in colors.keys():
		var share: float = float(colors[c]) / float(n)
		_check(absf(share - 1.0 / 3.0) < 0.03, "founder color %s ~1/3 (got %.3f)" % [c, share])
	_check(absf(float(met["medium"]) / float(n) - 0.5) < 0.03, "founder metabolism het ~1/2 (uniform alleles)")
	print("founder cannibal=%.4f brown=%.3f green=%.3f gray=%.3f" % [rate,
			float(colors["brown"]) / float(n), float(colors["green"]) / float(n), float(colors["gray"]) / float(n)])


func _test_crosses() -> void:
	var het: Dictionary = {"speed": ["S", "s"]}
	var loci: Array[String] = ["speed"]
	var rng: RandomNumberGenerator = _rng(5)
	var kids: Array = []
	for i: int in range(3000):
		kids.append(Genome.cross(_lib, het, het, rng, 0.0, loci))
	var observed: Dictionary = GenomeStats.count_phenotypes(_lib, kids, loci)
	var chi: Dictionary = GenomeStats.chi_square(observed, {"SS": 1.0, "Ss": 2.0, "ss": 1.0})
	_check(bool(chi["fits"]), "Ss x Ss gives 1:2:1 (chi2 %.2f, df %d)" % [float(chi["chi2"]), int(chi["df"])])
	# Self-fertilization is legal and only uses the parent's own alleles
	var selfed_ok: bool = true
	var seen_homs: int = 0
	for i: int in range(200):
		var kid: Dictionary = Genome.cross(_lib, het, het, rng, 0.0, loci)
		var pair: Array = kid["speed"]
		if pair.size() != 2 or not (["S", "s"].has(pair[0]) and ["S", "s"].has(pair[1])):
			selfed_ok = false
		if pair[0] == pair[1]:
			seen_homs += 1
	_check(selfed_ok, "self-fertilization yields valid pairs")
	_check(seen_homs > 0, "selfing a het produces homozygotes")
	var hom: Dictionary = {"speed": ["S", "S"]}
	var all_ss: bool = true
	for i: int in range(50):
		var kid2: Dictionary = Genome.cross(_lib, hom, hom, rng, 0.0, loci)
		if kid2["speed"] != ["S", "S"]:
			all_ss = false
	_check(all_ss, "SS selfed stays SS")


func _test_clone_and_mutation() -> void:
	var rng: RandomNumberGenerator = _rng(9)
	var g: Dictionary = EvoGenetics.random_founder(rng)
	var same: Dictionary = Genome.clone_with_mutation(_lib, g, rng, 0.0)
	_check(Genome.genotypes_equal(_lib, g, same), "clone at mutation 0 is identical")
	var hom: Dictionary = {
		"metabolism": ["M", "M"], "speed": ["S", "S"], "growth_rate": ["G", "G"],
		"color": ["Cb", "Cb"], "cannibal": ["K", "K"],
	}
	var changed: Dictionary = Genome.clone_with_mutation(_lib, hom, rng, 1.0)
	var all_changed: bool = true
	for id: String in EvoGenetics.LOCUS_IDS:
		var pair: Array = changed[id]
		var orig: Array = hom[id]
		if pair[0] == orig[0] or pair[1] == orig[1]:
			all_changed = false
	_check(all_changed, "mutation 1 changes every allele")
	var cross_changed: Dictionary = Genome.cross(_lib, hom, hom, rng, 1.0)
	var cross_all: bool = true
	for id: String in EvoGenetics.LOCUS_IDS:
		var pair2: Array = cross_changed[id]
		var orig2: Array = hom[id]
		if pair2[0] == orig2[0] or pair2[1] == orig2[1]:
			cross_all = false
	_check(cross_all, "cross at mutation 1 changes every allele")
	# Seeded determinism
	var a: Dictionary = Genome.cross(_lib, g, g, _rng(77), 0.05)
	var b: Dictionary = Genome.cross(_lib, g, g, _rng(77), 0.05)
	_check(Genome.genotypes_equal(_lib, a, b), "same seed gives same cross")


func _test_allele_helpers() -> void:
	var pop: Array[Dictionary] = [
		{"speed": ["S", "S"], "color": ["Cb", "Cg"]},
		{"speed": ["S", "s"], "color": ["Cy", "Cy"]},
		{"speed": ["s", "s"], "color": ["Cg", "Cb"]},
		{"speed": ["S", "s"], "color": ["Cy", "Cg"]},
	]
	var f: Dictionary = EvoGenetics.allele_frequencies(pop, "speed")
	_check(absf(float(f["S"]) - 0.5) < 1e-9 and absf(float(f["s"]) - 0.5) < 1e-9, "speed freq 4S/4s")
	var fc: Dictionary = EvoGenetics.allele_frequencies(pop, "color")
	_check(absf(float(fc["Cb"]) - 0.25) < 1e-9, "Cb freq 2/8")
	_check(absf(float(fc["Cg"]) - 0.375) < 1e-9, "Cg freq 3/8")
	_check(absf(float(fc["Cy"]) - 0.375) < 1e-9, "Cy freq 3/8")
	var counts: Dictionary = EvoGenetics.genotype_counts(pop, "speed")
	_check(counts["SS"] == 1 and counts["Ss"] == 2 and counts["ss"] == 1, "speed genotype counts")
	var cc: Dictionary = EvoGenetics.genotype_counts(pop, "color")
	_check(cc["CbCg"] == 2 and cc["CyCy"] == 1 and cc["CgCy"] == 1 and cc["CbCb"] == 0, "color genotype counts")
	_check(EvoGenetics.genotype_keys("color").size() == 6, "color has 6 genotype keys")
	var empty: Array[Dictionary] = []
	var fe: Dictionary = EvoGenetics.allele_frequencies(empty, "speed")
	_check(float(fe["S"]) == 0.0 and float(fe["s"]) == 0.0, "empty population gives zero freqs")
	var homo: Array[Dictionary] = [{"speed": ["S", "S"]}, {"speed": ["S", "S"]}]
	_check(float(EvoGenetics.allele_frequencies(homo, "speed")["S"]) == 1.0, "fixed allele freq 1.0")
