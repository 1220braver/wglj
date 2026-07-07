extends Node
## 输入层 — 读取并缓存每帧的输入状态。
## 所有 action 名称通过 @export 暴露，方便在 Inspector 中调整。

## ── Action 名称 ──
@export var action_move_left: String = "move_left"
@export var action_move_right: String = "move_right"
@export var action_jump: String = "jump"
@export var action_attack: String = "attack"
@export var action_skill: String = "skill"
@export var action_dash: String = "dash"
@export var action_interact: String = "interact"
@export var action_pause: String = "pause"

## ── 每帧缓存结果 ──
var direction: float = 0.0
var jump_just_pressed: bool = false
var attack_just_pressed: bool = false
var skill_just_pressed: bool = false
var dash_just_pressed: bool = false
var interact_just_pressed: bool = false
var pause_just_pressed: bool = false

func _physics_process(_delta: float) -> void:
	direction = Input.get_axis(action_move_left, action_move_right)
	jump_just_pressed = Input.is_action_just_pressed(action_jump)
	attack_just_pressed = Input.is_action_just_pressed(action_attack)
	skill_just_pressed = Input.is_action_just_pressed(action_skill)
	dash_just_pressed = Input.is_action_just_pressed(action_dash)
	interact_just_pressed = Input.is_action_just_pressed(action_interact)
	pause_just_pressed = Input.is_action_just_pressed(action_pause)
