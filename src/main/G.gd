extends Reference
class_name G

const LAYER_TEAM1 = 1
const LAYER_TEAM1_VAL = 2
const LAYER_TEAM2 = 2
const LAYER_TEAM2_VAL = 4
const LAYER_FLOWEREXCL_VAL = 32

const GAME_LENGTH = 300
const MAX_PLAYERS = 10

const TEAM1_CHAT_COLOR = "yellow"
const TEAM2_CHAT_COLOR = "aqua"

enum FlowerType { NORMAL, WEAPON, SUPER }

enum ObjectType { LADYBUG = 5 }

const SOUNDS = {
	"swish": preload("res://sounds/swish-9.wav"),
	"tick": preload("res://sounds/UI_Quirky8.wav"),
	"start": preload("res://sounds/UI_Quirky27.wav"),
	"flower_spawn": preload("res://sounds/UI_Quirky_49.wav"),
	"super_spawn": preload("res://sounds/Bells6.wav"),
	#"nectar_collect": "", TODO
	#"weapon_collect": "",
	"boost": preload("res://sounds/swish-9-long.wav"),
	"pass": preload("res://sounds/swish-13.wav"),
	"drop": preload("res://sounds/thwack-02.wav"),
	"pickup": preload("res://sounds/UI_Quirky16.wav"),
	"shoot": preload("res://sounds/swish-3-slime_01.wav"),
	"hit": preload("res://sounds/thwack-07.wav"),
	"score": preload("res://sounds/SynthChime10.wav")
}

const NAMES = [
	"Bumble",
	"Buzz",
	"Honey",
	"Miele",
	"Sting",
	"Spike",
	"Queenie",
	"Sugar",
	"Polly",
	"Kiiro",
	"Stripes",
	"Api",
	"Sweetie",
	
	"Barry",
	"Beetie",
	"Beatrice",
	"Beatrix",
	"Bernie",
	"Bellamy",
	"Buzter",
	"Beeauty",
	"Abbee",
	"Barnabee",
	"Beeanca",
	"Bobbee",
	"Colbee",
	
	"Zip",
	"Zipper",
	"Zippy",
	"Zoop",
	"Zappy",
	"Hazel",
	"Liz",
	"Jazzie",
	"Suzie",
	"Zoe",
	"Eliza",
	"Zia",
	"Zelda",
	"Oz",
	"Ozzy",
	"Zora",
	"Zeppie",
	"Zella",
	"Dizzy",
	"Fizz",
	"Breezy",
	
	"Jasmine",
	"Violet",
	"Azalea",
	"Ivy",
	"Iris",
	"Zinnia",
	"Petal",
	"Lily",
	"Flora",
	"Daisy",
	"Fleur",
	"Marigold",
	"Blossom",
	"Rosa",
	
	"Bumbledore",
	"ObeeWan",
	"Beeyonce",
	"Beethoven",
	
]

const TEAM_NAMES = [
	"Pollination",
	"Honeycomb",
	"Ambrosia",
	"Apis Mellifera",
	"Apicultural",
	"Aerial Drones",
	"Beegonias",
	"Powers That Bee",
	"Let It Bee",
	"Bee Prepared",
	"Buzz N Roses",
	"One Buzz",
	"School Buzz",
	"What Is Buzz",
	"Fuzzy Wuzzy",
	"Buzzy Logic",
	"Hawaii Hive-O",
	"I Hive A Dream",
	"Drama Queens",
	"You Is Bee",
	"Wanna Bees",
	"Vitamin Bee",
	"Bee Yourself",
	"Yellow Jackets",
	"Pollen In Love",
	"Un-Bee-Lievable",
	"Bees-ness Time",
	"Buzz Words",
]

const MESSAGES = {
	"score": [
		"SCORE! [color={TEAMCOLOR}]{PLAYER}[/color] earns {POINTS} points for Team [color={TEAMCOLOR}]{TEAMNAME}[/color]!",
		"[color={TEAMCOLOR}]{PLAYER}[/color] scores! Team [color={TEAMCOLOR}]{TEAMNAME}[/color] gains {POINTS} points!",
		"[color={TEAMCOLOR}]{PLAYER}[/color] scores! That's {POINTS} points for team [color={TEAMCOLOR}]{TEAMNAME}[/color]!",
		"{POINTS} points to team [color={TEAMCOLOR}]{TEAMNAME}[/color], thanks to that amazing play by [color={TEAMCOLOR}]{PLAYER}[/color]!"
	],
	"superscore": [
		"Team [color={TEAMCOLOR}]{TEAMNAME}[/color] has collected the super bloom and earned {POINTS} points!",
		"The super bloom has been collected! Team [color={TEAMCOLOR}]{TEAMNAME}[/color] gains {POINTS} points!"
	],
	"ladybugscore": [
		"[color={TEAMCOLOR}]{PLAYER}[/color] caught a lady bug and earned {POINTS} points!"
	],
	"superbloom": [
		"A [color=purple]SUPER FLOWER[/color] has bloomed! The team to collect it will gain 25 points!",
		"Another 25 points are available to the first team to collect the [color=purple]SUPER FLOWER[/color] that just bloomed!"
	],
	"ladybugswarm": [
		"A [color=#E75480]LADY BUG SWARM[/color] is passing through! Catch ladybugs to earn points."
	]
}
