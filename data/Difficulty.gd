# Difficulty.gd
# Every difficulty knob in one place, so the game can be tuned without
# hunting through Enemy.gd, Room.gd and the bosses. Era 1 stays gentle while
# the player learns; each later era asks a little more. Floors past 5 (other
# worlds) count as era 5.
#
# Change a number here, play a run, and see. tools/difficultytest.gd prints
# the resulting table for every era.
extends RefCounted

const LAST_ERA := 5

# ── Ordinary animals ──
# Health on top of each animal's own per-floor growth: x1.0 in era 1,
# +12% per era after (x1.48 in era 5)
const ENEMY_HEALTH_PER_ERA := 0.12
# Movement: +3% per era (x1.12 in era 5). Kept small so dodging on a touch
# stick stays readable.
const ENEMY_SPEED_PER_ERA := 0.03
# Shooters fire sooner: shot delay -5% per era (x0.80 in era 5)
const ENEMY_FIRE_PER_ERA := 0.05
const ENEMY_FIRE_MIN := 0.75
# Extra animals per fight room, by era (on top of 3 to 3+era)
const ROOM_EXTRA_ANIMALS := [0, 0, 1, 1, 2]
# Chance a fight room draws a second group, by era (0 = never)
const WAVE_CHANCE := [0.0, 0.22, 0.26, 0.30, 0.34]
# From this era, an elder (the ink-circled big old animal) bites for a whole
# heart instead of half. Elders are easy to spot, so this stays fair.
const ELDER_HEAVY_FROM_ERA := 4
const ELDER_HEAVY_DAMAGE := 2

# ── Free healing ──
# A kill leaves a pickup this often (was 0.35)
const KILL_DROP_CHANCE := 0.28
# Of those pickups, this share is a heart rather than a coin (was 0.30)
const DROP_HEART_SHARE := 0.25
# Of those hearts, this share is a whole heart rather than half (was 0.70)
const DROP_FULL_HEART_SHARE := 0.6
# A cleared fight room leaves a pickup this often (was 0.65; a room with a
# second group always pays out)
const CLEAR_DROP_CHANCE := 0.5

# ── Bosses ──
# Health: x1.15 in era 1, +5% per era after (x1.35 in era 5)
const BOSS_HEALTH_BASE := 1.15
const BOSS_HEALTH_PER_ERA := 0.05
# Bosses spend less time circling and recovering between attacks: the clock
# in these calm states runs this much faster. Wind-ups (the tells) are not
# touched, so every attack is still shown as clearly as before.
const BOSS_REST_SPEED := 1.3
const BOSS_REST_STATES := ["cruise", "recover", "wander", "stalk", "approach", "drift", "feed"]

static func era(floor_number: int) -> int:
	return clampi(floor_number, 1, LAST_ERA)

static func enemy_health_mult(floor_number: int) -> float:
	return 1.0 + ENEMY_HEALTH_PER_ERA * (era(floor_number) - 1)

static func enemy_speed_mult(floor_number: int) -> float:
	return 1.0 + ENEMY_SPEED_PER_ERA * (era(floor_number) - 1)

static func enemy_fire_delay_mult(floor_number: int) -> float:
	return max(ENEMY_FIRE_MIN, 1.0 - ENEMY_FIRE_PER_ERA * (era(floor_number) - 1))

static func room_extra_animals(floor_number: int) -> int:
	return ROOM_EXTRA_ANIMALS[era(floor_number) - 1]

static func wave_chance(floor_number: int) -> float:
	return WAVE_CHANCE[era(floor_number) - 1]

static func elder_damage(floor_number: int, base_damage: int) -> int:
	if base_damage <= 0 or era(floor_number) < ELDER_HEAVY_FROM_ERA:
		return base_damage
	return max(base_damage, ELDER_HEAVY_DAMAGE)

static func boss_health_mult(floor_number: int) -> float:
	return BOSS_HEALTH_BASE + BOSS_HEALTH_PER_ERA * (era(floor_number) - 1)

static func boss_clock(state: String) -> float:
	return BOSS_REST_SPEED if state in BOSS_REST_STATES else 1.0
