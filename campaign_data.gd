extends RefCounted
## A finite, ordered campaign. Each entry is a spawn list, never an endless timer.
const TITLES = ["非洲草原", "埃及金字塔", "中国长城"]
const SUBTITLES = ["日落草原 · 净化感染兽群", "沙海遗迹 · 唤醒的诅咒", "万里雄关 · 陶俑军阵"]
const ENEMY_NAMES = [
	["感染灰狼","疾奔野狼","铁背野猪","疫毒雄狮","感染狮王"],
	["裹尸木乃伊","豺首木乃伊","王陵守卫","咒术木乃伊","法老王"],
	["陶俑步卒","陶俑斥候","重甲陶俑","陶俑弩手","陶俑将军"]
]
const WAVES = [
	[[0,0,1,0,2,1], [0,1,2,0,3,1,2,0], [1,0,2,3,1,0,2,4]],
	[[0,1,0,2,0,1,3,0], [1,2,0,3,1,0,2,3,0,1], [0,2,1,3,0,2,1,3,0,4]],
	[[0,1,2,0,3,1,0,2,3,0], [1,2,3,0,1,2,0,3,1,2,0,3], [2,0,3,1,2,0,3,1,2,0,3,4]]
]
const COLORS = [Color("e8b653"),Color("e6bc75"),Color("92c4ad")]
const SKY = [Color("e9b57a"),Color("dbaf77"),Color("779da9")]
const DIFFICULTIES = ["简单","普通","困难"]
const BOSS_HP = [600.0,900.0,1200.0]

static func total(stage: int) -> int:
	var count := 0
	for wave in WAVES[stage]:
		count += wave.size()
	return count

static func stats(stage: int, kind: int, base: Dictionary, difficulty := 1) -> Dictionary:
	var result := base.duplicate()
	result.hp = BOSS_HP[stage] if kind==4 else base.hp*(1.0+stage*0.15)
	result.damage = base.damage*(1.0+stage*0.12)
	result.scale = (1.6 if stage==0 else 1.9) if kind==4 else base.scale
	result.color = [Color("8b935e"),Color("c8b58d"),Color("aa7857")][stage]
	result.title = ENEMY_NAMES[stage][kind]
	var power := Vector3.ONE
	if difficulty==0: power = Vector3(0.8,0.8,0.8)
	elif difficulty==2:
		power = [Vector3(1.1,1.1,1.0),Vector3(1.15,1.15,1.15),Vector3(1.2,1.2,1.2)][stage]
	result.hp *= power.x
	result.speed *= power.y
	result.damage *= power.z
	return result
