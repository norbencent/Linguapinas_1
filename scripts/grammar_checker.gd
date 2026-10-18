class_name GrammarChecker
extends RefCounted
## Checks a sentence the player wrote against a correct sentence from the
## game's sentence bank and says exactly what is wrong:
##   - misspelled words ("tubg" should be "tubig")
##   - missing words, with the grammar tip that explains them when there is one
##   - extra words
##   - wrong word order (the right words, in the wrong places)
## Capital letters and punctuation are ignored (a missing "?" is only noted).
##
## It compares with sentences the game knows; it is not a full grammar
## engine, so a correct sentence that is not in the bank is reported as
## "not one of the sentences I know".


## Result: {"ok": bool, "issues": Array[String], "notes": Array[String],
## "expected": String, "score": float (0..1, how close)}
static func check(given: String, expected: String, tips: Array = []) -> Dictionary:
	var g := words(given)
	var e := words(expected)
	var result := {"ok": false, "issues": [], "notes": [], "expected": expected, "score": 0.0}
	if g.is_empty():
		result.issues.append("Write a sentence first.")
		return result
	if expected.strip_edges().ends_with("?") and not given.strip_edges().ends_with("?"):
		result.notes.append("Questions end with a question mark (?).")
	if g == e:
		result.ok = true
		result.score = 1.0
		return result

	# Same words, different order.
	var gs := g.duplicate()
	var es := e.duplicate()
	gs.sort()
	es.sort()
	if gs == es:
		result.issues.append("Word order: you have the right words, but the order should be \"%s\"." % " ".join(e))
		result.issues.append_array(_order_tips(tips))
		result.score = 0.8
		return result

	# Align the two sentences word by word (spelling mistakes count as a match).
	var steps := _align(g, e)
	var matched := 0
	var moved: Array = []
	var missing: Array = []
	var extra: Array = []
	for st in steps:
		match st[0]:
			"same":
				matched += 1
			"spell":
				matched += 1
				result.issues.append("Spelling: \"%s\" should be \"%s\"." % [st[1], st[2]])
			"missing":
				missing.append(st[2])
			"extra":
				extra.append(st[1])
	# A word that is both "missing" and "extra" was only put in the wrong place.
	for w in missing.duplicate():
		if w in extra:
			missing.erase(w)
			extra.erase(w)
			moved.append(w)
	for w in moved:
		result.issues.append("Word order: \"%s\" is in the wrong place." % w)
	for w in missing:
		result.issues.append("Missing word: \"%s\"." % w + _tip_for(w, tips))
	for w in extra:
		result.issues.append("Extra word: \"%s\" does not belong here." % w)
	result.score = float(matched + moved.size()) / maxf(1.0, maxf(e.size(), g.size()))
	if result.issues.is_empty():
		result.ok = true
		result.score = 1.0
	return result


## Finds the closest sentence in [param sentences] (rows with "native" and
## "english") and checks against it. Adds "match" (the row) and "known".
static func check_free(given: String, sentences: Array, tips: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1.0
	for s in sentences:
		var sc := similarity(given, s.native)
		if sc > best_score:
			best_score = sc
			best = s
	if best.is_empty() or best_score < 0.34:
		return {"ok": false, "known": false, "issues": ["This is not one of the sentences I know yet, so I cannot check it."],
			"notes": [], "expected": "", "score": 0.0, "match": {}}
	var r := check(given, best.native, tips)
	r["known"] = true
	r["match"] = best
	return r


## 0..1: how many words two sentences share (spelling slips count).
static func similarity(a: String, b: String) -> float:
	var wa := words(a)
	var wb := words(b)
	if wa.is_empty() or wb.is_empty():
		return 0.0
	var hits := 0
	for w in wa:
		for x in wb:
			if w == x or _close(w, x):
				hits += 1
				break
	return float(hits) / maxf(wa.size(), wb.size())


static func words(text: String) -> Array:
	var cleaned := ""
	for ch in text.to_lower():
		cleaned += ch if (ch.to_upper() != ch.to_lower() or ch in "0123456789'-ñ") else " "
	return Array(cleaned.split(" ", false))


static func _close(a: String, b: String) -> bool:
	if a == b:
		return true
	var allowed := 1 if maxi(a.length(), b.length()) <= 5 else 2
	return absi(a.length() - b.length()) <= allowed and _distance(a, b) <= allowed


static func _distance(a: String, b: String) -> int:
	var prev: Array = range(b.length() + 1)
	for i in a.length():
		var cur: Array = [i + 1]
		for j in b.length():
			cur.append(mini(mini(cur[j] + 1, prev[j + 1] + 1), prev[j] + (0 if a[i] == b[j] else 1)))
		prev = cur
	return prev[b.length()]


## Word alignment (edit distance over words). Steps: ["same", g, e],
## ["spell", g, e], ["missing", "", e], ["extra", g, ""].
static func _align(g: Array, e: Array) -> Array:
	var n := g.size()
	var m := e.size()
	var cost: Array = []
	for i in n + 1:
		var row: Array = []
		for j in m + 1:
			row.append(0)
		cost.append(row)
	for i in n + 1:
		cost[i][0] = i
	for j in m + 1:
		cost[0][j] = j
	for i in range(1, n + 1):
		for j in range(1, m + 1):
			var sub: int = 0 if g[i - 1] == e[j - 1] else (1 if _close(g[i - 1], e[j - 1]) else 3)
			cost[i][j] = mini(cost[i - 1][j - 1] + sub, mini(cost[i - 1][j] + 2, cost[i][j - 1] + 2))
	var steps: Array = []
	var i := n
	var j := m
	while i > 0 or j > 0:
		if i > 0 and j > 0:
			var sub: int = 0 if g[i - 1] == e[j - 1] else (1 if _close(g[i - 1], e[j - 1]) else 3)
			if cost[i][j] == cost[i - 1][j - 1] + sub and sub < 3:
				steps.push_front(["same" if sub == 0 else "spell", g[i - 1], e[j - 1]])
				i -= 1
				j -= 1
				continue
		if j > 0 and (i == 0 or cost[i][j] == cost[i][j - 1] + 2):
			steps.push_front(["missing", "", e[j - 1]])
			j -= 1
		else:
			steps.push_front(["extra", g[i - 1], ""])
			i -= 1
	return steps


## The language's grammar tip that mentions [param word], if any.
static func _tip_for(word: String, tips: Array) -> String:
	for t in tips:
		var text := str(t.get("tip", t)) if t is Dictionary else str(t)
		if word in words(text):
			return " Tip: " + text
	return ""


## The first grammar tip that shares a word with [param sentence].
static func _tip_for_sentence(sentence: String, tips: Array) -> String:
	var sw := words(sentence)
	for t in tips:
		var text := str(t.get("tip", t)) if t is Dictionary else str(t)
		for w in words(text):
			if w.length() >= 2 and w in sw:
				return text
	return ""


static func _order_tips(tips: Array) -> Array:
	for t in tips:
		var text := str(t.get("tip", t)) if t is Dictionary else str(t)
		if "first" in text.to_lower() or "order" in text.to_lower():
			return ["Tip: " + text]
	return []
