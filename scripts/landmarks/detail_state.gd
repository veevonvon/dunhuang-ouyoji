extends RefCounted

const Patterns = preload("res://scripts/landmarks/detail_patterns.gd")
const SHUFFLES := [[1,2,0],[2,0,1],[0,2,1],[2,1,0],[1,0,2]]
var kind: String
var motif: String
var reflected_pair := false
var pieces: Array
var seed_value: int
var fronts: Array
var backs: Array
var cells: Array[int]
var pitches: Array[int] = []
var sequence: Array
var turns: Array[int] = []
var sightlines: Array[int] = []
var found: Array[int] = []
var selected := -1
var hint := false
var message := ""
var done := false

func _init(site: Dictionary, detail: Dictionary) -> void:
	kind=str(detail.kind)
	reflected_pair=(site.id=="tiantishan" and detail.id=="reservoir") or (site.id=="jiuquan_spring" and detail.id=="lake_pavilion")
	motif=str(detail.motif)
	pieces=detail.pieces.duplicate()
	seed_value=(str(site.id)+"/"+str(detail.id)).hash()
	cells=Patterns.subject(motif,pieces,seed_value)
	fronts=SHUFFLES[seed_value%5].duplicate()
	backs=SHUFFLES[(seed_value%5+1+int(seed_value/41.)%4)%5].duplicate()
	sequence=SHUFFLES[int(seed_value/11.)%5].duplicate()
	var offset:=int(seed_value/7.)%5
	for i in 3:
		pitches.append((i*2+offset)%5)
		turns.append(1+(int(seed_value/pow(5,i))%3))
		sightlines.append(int(seed_value/pow(7,i+1))%4)

func value_at(index: int) -> int:
	return int(backs[index-3]) if index>=3 else int(fronts[index])

func index_of(value: int, lower := false) -> int:
	return (3+backs.find(value)) if lower else fronts.find(value)

func is_marked(index: int) -> bool:
	return value_at(index) in found

func give_hint() -> void:
	hint=true
	match kind:
		"trace","order": message="下一处是「%s」。" % pieces[found.size()]
		"pair":
			message="选一张彩稿，找水面下上下颠倒的影子。" if reflected_pair else "找对应的轮廓。先选一张彩稿，再碰和它形状相同的墨样。"
		"turn": message="点一下转一格，让内圈的金尖对上外圈的朱红刻线。"
		"echo": message="点「听示范」，看看哪三幅画依次亮起，再照着敲。"
		"uncover": message="手指在浅色纸灰上轻轻擦一下，也可以直接点开。"

func act(index: int) -> String:
	if done: return ""
	var piece:=value_at(index)
	if piece in found and kind!="echo": return ""
	match kind:
		"trace","order":
			if piece!=found.size():
				message="先找「%s」，这张画可以稍后再碰。" % pieces[found.size()]
				return "miss"
		"pair":
			if selected<0 or (selected<3)==(index<3):
				selected=index
				if reflected_pair:
					message="已选「%s」，找水里的倒影。" % pieces[piece] if index<3 else "已选倒影，在上排找它原来的样子。"
				else: message="已选「%s」，找另一排相同的轮廓。" % pieces[piece]
				return "step"
			var previous:=value_at(selected)
			selected=-1
			if previous!=piece:
				message="这两张没有对上，再看尖端朝哪边。" if reflected_pair else "两张轮廓有点不同，再看看边上的线条。"
				return "miss"
		"turn":
			turns[piece]=(turns[piece]+1)%4
			if turns[piece]!=0:
				message="转过一格，金尖正向朱线靠近。"
				return "step"
		"echo":
			if piece!=int(sequence[found.size()]):
				message="这声稍晚一些。可以再听，也可以接着试。"
				return "miss"
	found.append(piece)
	hint=false
	selected=-1
	done=found.size()==3
	message="已经找到「%s」。" % pieces[piece]
	return "win" if done else "step"
