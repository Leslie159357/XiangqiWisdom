# 识别链路逆向（续）：透视与 dk/dt

对象：`com.su.chessaihelper` v66 主二进制（sha256 `305e71e3…66dff`）。

## 1. 原版没有自动透视校正

`CropSelectionView` 的全部方法（0x10005d30c–0x10005e514）：

```
initWithAspectRatio:      // 固定宽高比的裁剪框
layoutSubviews / drawRect:
handlePan: / handlePinch:
resetSelectionRectAnimated:
handleCornerDrag:
cornerForTag:inRect: / oppositeCornerForTag:inRect:
applyRectBounds:
updateCornerDots:
selectedRectInImage:      // 把裁剪框映射回图片坐标
aspectRatio / setAspectRatio: / selectionRect / setSelectionRect:
cornerDots / activeCorner / fixedCornerPoint / initialRect / initialTouchPoint
```

它是个**手动拖拽的矩形裁剪框**（四角可拖、可捏合缩放、固定宽高比），产出的是 `CGRect`，不是四点坐标。

`BoardView` 侧同样没有单应/透视相关方法（只有 `drawBoard`、`layerForCenter:type:`、`pipBoardWithScale:`、`demoBoardWithScale:`）。

结论：**原版的「校正」就是用户手动框一个轴对齐矩形，然后按矩形做线性映射。** 我们复刻里的 `bd` 框 → 9×10 网格投影与原版同级，不存在「原版有、我们没有」的透视环节。斜视角下错格是原版同样存在的问题，靠用户把框摆正来规避。

## 2. dk / dt 是揭棋（暗棋）标记，不是角点

主二进制里存在 `Dark` / `FLIP` / `Hidden` / `flip` / `dark` 字符串组，配合 17 类检测集：

```
bc rc bh rh be re bg rg bk rk bp rp bs rs   // 14 种正常棋子
dk dt bd                                    // 2 个特殊 + 1 个棋盘
```

`bd` = board（棋盘整体框），`dk` = dark king（暗棋的将/帅），`dt` = dark tile（背面朝上的暗子）。17 类正好覆盖「明棋 + 暗棋 + 棋盘」，与 App 的揭棋模式对应。

对普通对局：`dk`/`dt` 不会出现，忽略即可。这也是我们把 17 类全保留、但 FEN 映射只认 14 种的原因。

## 3. 结论

| 原先列为「未完成」 | 实际状态 |
|---|---|
| 透视校正（四点单应） | **原版不存在**。原版是手动矩形裁剪 + 线性映射，我们的实现已对齐 |
| `dk`/`dt` 语义 | 已确认：揭棋模式的暗棋标记，普通对局不触发 |
| Zobrist 对齐 | 已完成，初始局面命中 8 条着法 |
| 实时识别稳定性 | 0.8s 节流是当前实现参数，属调优而非逆向缺口 |
