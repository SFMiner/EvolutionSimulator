class_name EvoGenetics
extends RefCounted
## Single place that defines the simulator's loci and maps genotype -> `genome` phenotype.
## Genotype: {locus_id: [allele, allele]} (engine shape). Phenotype (`Organism.genome`) keeps
## the old shape: metabolism/speed/growth_rate/color strings and a `cannibal` bool.

const METABOLISM: String = "metabolism"
const SPEED: String = "speed"
const GROWTH_RATE: String = "growth_rate"
const COLOR: String = "color"
const CANNIBAL: String = "cannibal"

const LOCUS_IDS: Array[String] = ["metabolism", "speed", "growth_rate", "color", "cannibal"]

## Today's founder chance of being a cannibal (old `randf() < 0.2`).
const FOUNDER_CANNIBAL_PROBABILITY: float = 0.2

static var _library: GenomeLibrary = null


static func get_library() -> GenomeLibrary:
	if _library == null:
		_library = build_library()
	return _library


static func build_library() -> GenomeLibrary:
	var lib: GenomeLibrary = GenomeLibrary.new()
	lib.add_locus(_make_locus(METABOLISM, "Metabolism", ["M", "m"], GenomeLocus.Dominance.INCOMPLETE,
			{"MM": "high", "Mm": "medium", "mm": "low"}))
	lib.add_locus(_make_locus(SPEED, "Speed", ["S", "s"], GenomeLocus.Dominance.INCOMPLETE,
			{"SS": "fast", "Ss": "medium", "ss": "slow"}))
	lib.add_locus(_make_locus(GROWTH_RATE, "Growth rate", ["G", "g"], GenomeLocus.Dominance.INCOMPLETE,
			{"GG": "fast", "Gg": "normal", "gg": "slow"}))
	lib.add_locus(_make_locus(COLOR, "Color", ["Cb", "Cg", "Cy"], GenomeLocus.Dominance.COMPLETE,
			{"Cb": "brown", "Cg": "green", "Cy": "gray"}))
	lib.add_locus(_make_locus(CANNIBAL, "Cannibal", ["K", "k"], GenomeLocus.Dominance.COMPLETE,
			{"K": "false", "k": "true"}))
	return lib


static func _make_locus(id: String, display_name: String, alleles: Array[String],
		dominance: GenomeLocus.Dominance, names: Dictionary) -> GenomeLocus:
	var locus: GenomeLocus = GenomeLocus.new()
	locus.id = id
	locus.display_name = display_name
	locus.alleles = alleles
	locus.dominance = dominance
	locus.dominance_rank = alleles.duplicate()
	var phenotypes: Dictionary = {}
	for key: String in names.keys():
		phenotypes[key] = {"name": str(names[key])}
	locus.phenotypes = phenotypes
	return locus


## Founder allele weights. Cannibal: P(kk) = p_k^2 = the old 20% rate. Color: weights chosen so
## the phenotype split is exactly 1/3 brown, 1/3 green, 1/3 gray like the old uniform pick.
## Other loci stay uniform (1:2:1 genotypes), since an even 1/3 split is impossible with two alleles.
static func founder_weights() -> Dictionary:
	var p_k: float = sqrt(FOUNDER_CANNIBAL_PROBABILITY)
	var p_cy: float = sqrt(1.0 / 3.0)
	var p_cb: float = 1.0 - sqrt(2.0 / 3.0)
	return {
		CANNIBAL: {"K": 1.0 - p_k, "k": p_k},
		COLOR: {"Cb": p_cb, "Cg": 1.0 - p_cb - p_cy, "Cy": p_cy},
	}


static func random_founder(rng: RandomNumberGenerator) -> Dictionary:
	return Genome.random_genotype(get_library(), rng, LOCUS_IDS, founder_weights())


## Expressed phenotype in the exact legacy `genome` shape.
static func to_genome(genotype: Dictionary) -> Dictionary:
	var lib: GenomeLibrary = get_library()
	var full: Dictionary = {}
	for id: String in LOCUS_IDS:
		if genotype.has(id):
			full[id] = genotype[id]
		else:
			full[id] = lib.get_locus(id).default_pair()  # partial genotype: fill the gap
	var raw: Dictionary = Genome.phenotype(lib, full)
	var out: Dictionary = {}
	for id: String in LOCUS_IDS:
		var entry: Dictionary = raw.get(id, {})
		var value: String = str(entry.get("name", ""))
		if id == CANNIBAL:
			out[id] = value == "true"
		else:
			out[id] = value
	return out


## Allele letters for display, one pair per locus, e.g. "Mm Ss gg CbCy Kk".
static func genotype_label(genotype: Dictionary) -> String:
	var lib: GenomeLibrary = get_library()
	var parts: PackedStringArray = PackedStringArray()
	for id: String in LOCUS_IDS:
		var locus: GenomeLocus = lib.get_locus(id)
		parts.append(locus.genotype_key(_pair(genotype, locus)))
	return " ".join(parts)


static func locus_name(locus_id: String) -> String:
	var lib: GenomeLibrary = get_library()
	if lib.has_locus(locus_id):
		return lib.get_locus(locus_id).display_name
	return locus_id


static func _pair(genotype: Dictionary, locus: GenomeLocus) -> Array:
	var raw: Variant = genotype.get(locus.id, null)
	if raw is Array and (raw as Array).size() == 2:
		return raw as Array
	return locus.default_pair()


## Fraction of each allele among all gene copies (2 per organism) at one locus. Sums to 1.
static func allele_frequencies(genotypes: Array[Dictionary], locus_id: String) -> Dictionary:
	var locus: GenomeLocus = get_library().get_locus(locus_id)
	var out: Dictionary = {}
	for allele: String in locus.alleles:
		out[allele] = 0.0
	if genotypes.is_empty():
		return out
	for genotype: Dictionary in genotypes:
		for token: Variant in _pair(genotype, locus):
			var allele: String = str(token)
			out[allele] = float(out.get(allele, 0.0)) + 1.0
	var total: float = 2.0 * float(genotypes.size())
	for allele: String in out.keys():
		out[allele] = float(out[allele]) / total
	return out


## All genotype keys for a locus in display order, e.g. ["SS", "Ss", "ss"].
static func genotype_keys(locus_id: String) -> Array[String]:
	var locus: GenomeLocus = get_library().get_locus(locus_id)
	var keys: Array[String] = []
	var n: int = locus.alleles.size()
	for i: int in range(n):
		for j: int in range(i, n):
			keys.append(locus.genotype_key([locus.alleles[i], locus.alleles[j]]))
	return keys


## Count of organisms per genotype key (every possible key is present, zero if unseen).
static func genotype_counts(genotypes: Array[Dictionary], locus_id: String) -> Dictionary:
	var locus: GenomeLocus = get_library().get_locus(locus_id)
	var out: Dictionary = {}
	for key: String in genotype_keys(locus_id):
		out[key] = 0
	for genotype: Dictionary in genotypes:
		var key: String = locus.genotype_key(_pair(genotype, locus))
		out[key] = int(out.get(key, 0)) + 1
	return out
