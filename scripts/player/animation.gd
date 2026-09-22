extends Node
## 动画层 — 状态机 + Sprite 动画切换。
## 通过 @export Dictionary 映射状态→动画，新增状态只需改 Inspector。
## 锁定状态列表控制哪些状态下暂停物理处理。

## ── 状态枚举 (可扩展) ──
enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	ATTACK,
	HURT,
	DEAD,
	# 预留
	DASH,
	SKILL,
	CLIMB,
	INTERACT,
}

## ── 状态 → 动画 映射 (key 为 State 枚举值) ──
@export var anim_map: Dictionary = {
	State.IDLE:   "idle",
	State.RUN:    "run",
	State.JUMP:   "jump",
	State.FALL:   "jump",   # 下落复用 jump，有 fall 精灵后改 "fall"
	State.ATTACK: "attack",
	State.HURT:   "hurt",
	State.DEAD:   "dead",
}

## ── 锁定状态（这些状态下 Player 跳过物理处理）──
@export var locked_states: Array[int] = [State.DEAD]

const STATE_NAMES := ["IDLE", "RUN", "JUMP", "FALL", "ATTACK", "HURT", "DEAD"]

## ── 运行时 ──
var player: CharacterBody2D
var current_state: State = State.IDLE
var _hurt_timer: float = 0.0

## Debug
@export var debug_state: String = ""

func _ready() -> void:
	player = get_parent() as CharacterBody2D

## 每帧由 Player 调用
func update(input_dir: float) -> void:
	debug_state = STATE_NAMES[current_state]

	# ATTACK 动画播完自动回 IDLE
	if current_state == State.ATTACK:
		if _is_playing("attack"):
			return
		_play_anim(State.IDLE)
		current_state = State.IDLE

	# HURT 持续 0.3s 后自动恢复
	if current_state == State.HURT:
		_hurt_timer += get_process_delta_time()
		if _hurt_timer < 0.3:
			return
		_hurt_timer = 0.0
		current_state = State.IDLE

	var next := _resolve_state(input_dir)
	set_state(next)

	# 水平翻转
	if input_dir != 0:
		if player.sprite: player.sprite.flip_h = input_dir < 0

## ── 根据物理状态决定新状态 ──
func _resolve_state(input_dir: float) -> State:
	if not player.is_on_floor():
		return State.FALL if player.velocity.y >= 0 else State.JUMP
	if input_dir != 0:
		return State.RUN
	return State.IDLE

## ── 切换状态（带去重）──
func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	_play_anim(new_state)

## ── 播放动画（从 anim_map 查表）──
func _play_anim(state: State) -> void:
	var anim_name: String = anim_map.get(state, "idle")
	player.sprite.play(anim_name)

## ── 便捷触发 ──
func trigger_attack() -> void:  set_state(State.ATTACK)
func trigger_hurt() -> void:
	_hurt_timer = 0.0
	set_state(State.HURT)
func trigger_dead() -> void:    set_state(State.DEAD)

## ── 查询 ──
func is_locked() -> bool:
	return int(current_state) in locked_states

func is_hurt() -> bool:
	return current_state == State.HURT

func is_dead() -> bool:
	return current_state == State.DEAD

func _is_playing(anim_name: String) -> bool:
	return player.sprite.is_playing() and player.sprite.animation == anim_name
