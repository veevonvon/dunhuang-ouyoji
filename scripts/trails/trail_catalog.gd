extends RefCounted

const TRAILS := {
	"wuwei": {
		"place":"武威", "title":"沙上驼踪", "seal":"驼铃纹", "encounter":"wuwei-camel", "kind":"track",
		"brief":"顺着双瓣蹄印，找回驼铃。", "guide":"认一认", "clue":"骆驼留下两瓣蹄印。\n尖尖朝着下一步。",
		"start":"从系着红绳的蹄印出发。", "step":"跟着蹄印尖尖的方向走。", "miss":"这串脚印走岔了，从亮起的蹄印接着走。",
		"route":[0, 2, 4, 5, 7], "nodes":[Vector2(84,239),Vector2(218,321),Vector2(225,149),Vector2(376,76),Vector2(374,254),Vector2(515,147),Vector2(626,301),Vector2(705,178)]
	},
	"zhangye": {
		"place":"张掖", "title":"一束泉光", "seal":"清泉纹", "encounter":"zhangye-wheel", "kind":"mirror",
		"brief":"把阳光送到泉边的水车。", "guide":"照到这里", "clue":"铜镜会让光拐弯。\n转一转，让水车亮起来。",
		"start":"点一下铜镜，看光往哪里走。", "step":"看看亮线尽头，再转下一面镜。",
		"source":Vector2i(0,2), "goal":Vector2i(4,0), "mirrors":[Vector2i(2,2),Vector2i(2,0)], "start_slash":[false,false]
	},
	"jiuquan": {
		"place":"酒泉", "title":"藤间寻露", "seal":"葡萄纹", "encounter":"jiuquan-grapes", "kind":"track",
		"brief":"带着露珠，沿绿藤浇葡萄。", "guide":"认一认", "clue":"叶尖上藏着小露珠。\n顺着有叶子的青藤走。",
		"start":"从红绳旁的小露珠出发。", "step":"下一片绿叶在哪根藤上？", "miss":"这段藤上没有露珠，回到亮起的绿叶吧。",
		"route":[0,1,3,6,7,8], "nodes":[Vector2(82,207),Vector2(205,296),Vector2(211,92),Vector2(347,204),Vector2(409,328),Vector2(469,84),Vector2(494,207),Vector2(630,98),Vector2(713,235)]
	},
	"jiayuguan": {
		"place":"嘉峪关", "title":"点亮关楼", "seal":"关城纹", "encounter":"jiayuguan-arch", "kind":"mirror",
		"brief":"接住灯光，照亮关城门。", "guide":"照到这里", "clue":"让灯光连过三面镜，\n在关楼前点起一盏灯。",
		"start":"从左边的小灯笼开始看。", "step":"沿着亮线找下一面铜镜。",
		"source":Vector2i(0,0), "goal":Vector2i(3,0), "mirrors":[Vector2i(1,0),Vector2i(1,2),Vector2i(3,2)], "start_slash":[true,true,false]
	},
	"guazhou": {
		"place":"瓜州", "title":"合弦琵琶", "seal":"琵琶纹", "encounter":"guazhou-pipa", "kind":"register",
		"brief":"平移画带，把琴弦接起来。", "guide":"照着拼", "clue":"看琴弦和红飘带。\n让断开的两头接上。",
		"start":"点画带换一格，也可以左右滑。", "step":"对照小画，接好琴弦和红飘带。", "offsets":[-1,1,-1]
	},
	"dunhuang": {
		"place":"敦煌", "title":"月下莲影", "seal":"月莲纹", "encounter":"dunhuang-lotus", "kind":"register",
		"brief":"推动画带，合拢月下莲花。", "guide":"照着拼", "clue":"月牙在上，莲叶在下。\n花瓣和水纹要连起来。",
		"start":"点画带换一格，也可以上下滑。", "step":"找一找断开的花瓣和水面。", "offsets":[1,-1,1]
	}
}

static func get_trail(stage_id: String) -> Dictionary:
	return TRAILS.get(stage_id, {}).duplicate(true)
