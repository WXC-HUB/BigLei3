class_name DuelConfig
extends RefCounted
## 对战局的全部可调数值。Spec 明确要求「数值全部集中成一组常量」——实测平衡时
## 只改这一个文件，别把数字散回 main.gd 里去。

## 本地双实例用的默认端口与地址。房间码匹配和中继服务器不在 FEAT-001 范围内。
const DEFAULT_PORT := 8910
const DEFAULT_ADDRESS := "127.0.0.1"

## 对战双方共用一条血：PVE 伤害（踩雷/错旗/大怪）照旧扣它，对手的标雷伤害也扣它。
## 单机的 3 点血在「每标一个雷掉 1 点」的经济里撑不住，所以对战单独给 10 点。
const START_HP := 10
const START_GOLD := 10

## 每标出一个雷：对对手造成 MARK_DAMAGE，自己获得 MARK_GOLD。按雷逐个结算。
const MARK_DAMAGE := 1
const MARK_GOLD := 1

## 中场休息的自动开始倒计时。双方都点「准备好了」可以提前，挂机则等它归零。
const INTERMISSION_SECONDS := 30.0
