# Difficulty.gd
# Every difficulty knob in one place, so the game can be tuned without
# hunting through Enemy.gd, Room.gd and the bosses. kuro found the game too
# easy twice (PR #128, then 2026-11-25), so era 1 is harder too now and each
# later era asks more. Floors past 5 (other worlds) count as era 5.
#
# Change a number here, play a run, and see. tools/difficultytest.gd prints
# the resulting table for every era.
extends RefCounted

const LAST_ERA := 5

# ── Ordinary animals ──
# Health on top of each animal's own per-floor growth: x1.25 in era 1,
# +15% per era after (x1.85 in era 5)
const ENEMY_HEALTH_BASE := 1.25
const ENEMY_HEALTH_PER_ERA := 0.15
# Movement: x1.05 in era 1, +3.5% per era (x1.19 in era 5). Kept modest so
# dodging on a touch stick stays readable.
const ENEMY_SPEED_BASE := 1.05
const ENEMY_SPEED_PER_ERA := 0.035
# Shooters fire sooner: shot delay x0.90 in era 1, -6% per era (x0.66 in era 5)
const ENEMY_FIRE_BASE := 0.9
const ENEMY_FIRE_PER_ERA := 0.06
const ENEMY_FIRE_MIN := 0.6
# Extra animals per fight room, by era (on top of 3 to 3+era)
const ROOM_EXTRA_ANIMALS := [1, 1, 2, 2, 3]
# Chance a fight room draws a second group, by era (0 = never)
const WAVE_CHANCE := [0.15, 0.30, 0.35, 0.40, 0.45]
# From this era, an elder (the ink-circled big old animal) bites for a whole
# heart instead of half. Elders are easy to spot, so this stays fair.
const ELDER_HEAVY_FROM_ERA := 3
const ELDER_HEAVY_DAMAGE := 2
# Animals notice you from further away and sooner (their temper's radius and
# notice time, data/Fauna.gd TEMPERS)
const AGGRO_RADIUS_MULT := 1.3
const NOTICE_TIME_MULT := 0.65
# Smarter aim: spitters and lungers aim where you are heading, this share of
# a perfect lead (0 = at you, 1 = perfect intercept). Under 1 so weaving
# still dodges.
const SHOT_LEAD := 0.55
const LUNGE_LEAD := 0.35
# Lungers strike again sooner (x of their 2.0-3.2 s rest)
const LUNGE_REST_MULT := 0.75

# ── The player ──
# Invincible time after a hit, in seconds (was 1.0; heavy carapace doubles it)
const PLAYER_IFRAMES := 0.8

# ── Free healing ──
# A kill leaves a pickup this often (originally 0.35)
const KILL_DROP_CHANCE := 0.22
# Of those, this share leaves a heart; the rest leave nothing (they were
# shop coins until 2026-11-27) (originally 0.30)
const DROP_HEART_SHARE := 0.2
# Of those hearts, this share is a whole heart rather than half (originally 0.70)
const DROP_FULL_HEART_SHARE := 0.45
# A cleared fight room leaves a pickup this often (originally 0.65; a room
# with a second group always pays out)
const CLEAR_DROP_CHANCE := 0.4

# ── Bosses ──
# Health: x1.35 in era 1, +8% per era after (x1.67 in era 5)
const BOSS_HEALTH_BASE := 1.35
const BOSS_HEALTH_PER_ERA := 0.08
# Bosses spend less time circling and recovering between attacks: the clock
# in these calm states runs this much faster. Wind-ups (the tells) are not
# touched, so every attack is still shown as clearly as before.
const BOSS_REST_SPEED := 1.5
const BOSS_REST_STATES := ["cruise", "recover", "wander", "stalk", "approach", "drift", "feed"]

# ── The first world ──
# kuro (2026-11-26): everything in the first world moves slower, so a new
# player learns the controls before the pace picks up. Animals, their shots
# and the boss all run at this share of their speed on floor 1 (the shots
# fly as far, just slower). Main.generate_floor sets `pace` for the floor.
const FIRST_WORLD_PACE := 0.72
static var pace: float = 1.0

static func pace_for(floor_number: int) -> float:
	return FIRST_WORLD_PACE if floor_number <= 1 else 1.0

static func era(floor_number: int) -> int:
	return clampi(floor_number, 1, LAST_ERA)

# The Great Dying (data/Endgame.gd): its animals are the toughest survivors
const FINALE_ENEMY_HEALTH := 1.15

static func enemy_health_mult(floor_number: int) -> float:
	var m = ENEMY_HEALTH_BASE + ENEMY_HEALTH_PER_ERA * (era(floor_number) - 1)
	if preload("res://data/Worlds.gd").finale and floor_number >= 5:
		m *= FINALE_ENEMY_HEALTH
	if preload("res://data/Endgame.gd").deep_time():
		m *= preload("res://data/Endgame.gd").DEEP_ENEMY_HEALTH
	return m

static func enemy_speed_mult(floor_number: int) -> float:
	return ENEMY_SPEED_BASE + ENEMY_SPEED_PER_ERA * (era(floor_number) - 1)

static func enemy_fire_delay_mult(floor_number: int) -> float:
	return max(ENEMY_FIRE_MIN, ENEMY_FIRE_BASE - ENEMY_FIRE_PER_ERA * (era(floor_number) - 1))

static func room_extra_animals(floor_number: int) -> int:
	var E = preload("res://data/Endgame.gd")
	return ROOM_EXTRA_ANIMALS[era(floor_number) - 1] + (E.DEEP_EXTRA_ANIMALS if E.deep_time() else 0)

static func wave_chance(floor_number: int) -> float:
	return WAVE_CHANCE[era(floor_number) - 1]

static func elder_damage(floor_number: int, base_damage: int) -> int:
	if base_damage <= 0 or era(floor_number) < ELDER_HEAVY_FROM_ERA:
		return base_damage
	return max(base_damage, ELDER_HEAVY_DAMAGE)

static func boss_health_mult(floor_number: int) -> float:
	var E = preload("res://data/Endgame.gd")
	return (BOSS_HEALTH_BASE + BOSS_HEALTH_PER_ERA * (era(floor_number) - 1)) * (E.DEEP_BOSS_HEALTH if E.deep_time() else 1.0)

static func boss_clock(state: String) -> float:
	if not state in BOSS_REST_STATES:
		return 1.0
	var E = preload("res://data/Endgame.gd")
	return BOSS_REST_SPEED * (E.DEEP_BOSS_REST if E.deep_time() else 1.0)

# Where to aim at a moving target: `lead` of the way to a perfect intercept
static func lead_target(from: Vector2, target: Node2D, shot_speed: float, lead: float) -> Vector2:
	var pos = target.global_position
	var vel = target.get("velocity")
	if lead <= 0.0 or not (vel is Vector2) or shot_speed <= 0.0:
		return pos
	var t = from.distance_to(pos) / shot_speed
	return pos + vel * min(t, 1.2) * lead
