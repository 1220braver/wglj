# wglj

2D 横版动作游戏 Demo

## 技术栈
- Godot 4.3 + GDScript
- 状态机驱动的 Player 移动/跳跃/攻击系统
- HitBox/HurtBox 战斗框架（击退、命中反馈、无敌帧、音效）

## 玩法
- Player 移动、跳跃、近战攻击
- 5 只 Primitive Warrior 敌人（巡逻 + 追击 + 攻击 AI）
- Bone King Boss（PUNCH + JUMP_SLAM 双技能 + 阶段切换）
- 7 区域关卡：教学 / 战斗 / 平台 / 陷阱 / Boss 房
- HUD（HP条、敌人计数、Boss血条、Debug面板）
- SFX 音效系统
- 开场 / 通关文字动画

## 架构
- Player 拆分为 Input / Movement / Animation / Health / Attack 五组件
- 敌人 / Boss 使用统一 HurtBox + enum 状态机
- 占位美术全部使用 _draw() 像素风绘制
