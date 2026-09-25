extends RefCounted
## Only actual completed results are public; seed ratings are never exposed.
const CAST = {
	"Bit": [0, "81d9c4", "Teste de entrada"],
	"Tu": [0, "81d9c4", "Taça Aurora"], "Salvo": [1, "81d9c4", "Farol"],
	"Lira": [103, "bd9ee0", "Farol"], "Vértice": [108, "d28263", "Farol"],
	"Magnus": [11, "e8bd78", "Coroa"], "Bigorna": [4, "b99668", "Pedreira"],
	"Órbita": [2, "aaa7ed", "Órbita"], "Eclipse": [5, "8dbbd7", "Bastião"],
	"Broto": [3, "9ecb86", "Jardim"], "Rosca": [6, "d2b990", "Pêndulo"],
	"Faísca": [7, "7fe6ff", "Tempestade"], "Batida": [8, "c6ff4d", "Cristal"],
	"Gancho": [9, "ff5c8a", "Recife"], "Hélio": [10, "ffe45c", "Solar"]
}
# The cast was renamed with the new robots; results saved under the old names still resolve.
const LEGACY_NAMES = {"FAROLEIRO": "Salvo", "ASTRÓNOMO": "Órbita", "JARDINEIRO": "Broto", "MINEIRO": "Bigorna",
	"SENTINELA": "Eclipse", "RELOJOEIRO": "Rosca", "CAÇA-TROVÕES": "Faísca", "ALQUIMISTA": "Batida",
	"CORSÁRIO": "Gancho", "ARCONTE SOLAR": "Hélio", "AUREL": "Magnus", "AURORA": "Bit"}
static func public_name(value: String) -> String:
	if value.to_upper() == "SALVO": return "Salvo"
	return LEGACY_NAMES.get(value.to_upper(), value)
static func portrait_spec(cup, who: String) -> Array:
	if CAST.has(who): return CAST[who]
	for stage in range(cup.FULL_STAGES):
		for index in range(cup.QUALIFIERS):
			if cup.normal_name(stage, index) == who: return [100 + stage * cup.QUALIFIERS + index, Color.from_hsv(fmod((stage * cup.QUALIFIERS + index) * 0.618034, 1.0), 0.48, 0.91).to_html(false), "Qualificatórias"]
	return [101, "719ba3", "Chave regional"]
static func profile(cup, who: String) -> Dictionary:
	var p = {"name": who, "state": "ACTIVE", "wins": 0, "history": [], "eliminated_by": "", "sector": portrait_spec(cup, who)[2], "meeting": "Ainda por determinar", "tag": "PILOTO", "confirmed_only": false}
	if who == "Tu":
		p.state = "PLAYER"
		p.tag = "O TEU PERCURSO"
		p.wins = cup.wins
		for record in cup.history:
			p.history.append({"winner": "Tu", "loser": public_name(record.opponent), "score": "%s–%s" % record.score, "round": record.round})
		p.meeting = "Taça conquistada" if cup.wins >= cup.FULL_MATCHES else "Ronda %03d · %s" % [cup.wins + 1, cup.sector_label()]
		return p
	for r in cup.rounds:
		for fixture in r.fixtures:
			if who in [public_name(fixture.winner), public_name(fixture.loser)]: p.history.append(fixture.duplicate())
	for fixture in cup.world_results:
		if who in [fixture.winner, fixture.loser]: p.history.append(fixture.duplicate())
	for record in cup.history:
		if public_name(record.opponent) == who:
			p.history.append({"winner": "Tu", "loser": who, "score": "%s–%s" % record.score, "round": record.round})
	p.history.sort_custom(func(a, b): return a.round < b.round)
	for record in p.history:
		if public_name(record.winner) == who: p.wins += 1
		else:
			p.state = "ELIMINATED"
			p.eliminated_by = public_name(record.winner)
	p.tag = "4× CAMPEÃO · RUMO AO PENTA" if who == "Magnus" else ("PROMESSA" if who == "Lira" else ("REVELAÇÃO" if who == "Vértice" and cup.wins >= 4 else "PARTICIPANTE"))
	if who == "Magnus" and p.state != "ELIMINATED": p.state = "CHAMPION"
	if p.state == "ELIMINATED": p.meeting = "Fora da Taça · resultado confirmado"
	else:
		var current: Dictionary = cup.confirmed_match()
		if not current.is_empty() and current.name == who: p.meeting = "Próximo confronto contigo · confirmado"
		else: p.meeting = "Possível encontro · depende dos resultados"
	return p
static func fixtures(cup, round_index: int, page: int) -> Array:
	if cup.rounds.is_empty(): return []
	var matches: Array = cup.rounds[clampi(round_index, 0, cup.rounds.size() - 1)].fixtures
	return matches.slice(page * 8, mini(matches.size(), page * 8 + 8))
