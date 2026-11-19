# OBK 开局库与 Zobrist 算法（逆向实录）

对象：象棋智囊 `com.su.chessaihelper` v66 主二进制（已 FairPlay 解密，sha256 `305e71e3…66dff`）。

## 1. bh.obk 是 SQLite

```
SQLite format 3 · 5,156,864 bytes
table bhobk(id INTEGER PK, vkey INTEGER, vmove INTEGER, vscore INTEGER,
             vwin INTEGER, vdraw INTEGER, vlost INTEGER, vvalid INTEGER,
             vmemo BLOB, vindex INTEGER)
records: 106,135
```

查询语句（主二进制 `__cstring` 实证）：

```sql
SELECT * FROM bhobk WHERE cast(vkey as double) = %lf and vvalid = 1;
SELECT * FROM bhobk WHERE cast(vkey as integer) = %ld and ...
```

也就是说：库里存的是 **局面 Zobrist key**，运行时算当前局面的 key 直接查表。

## 2. Zobrist 算法（完整还原）

方法：`ZobristUtils::getZobristFromBoard:redGo:leftRightSwap:` @ `0x1000868c4`

反编译等价代码：

```c
static const int   kCoord[90];       // DAT_1000de0a0
static const uint64_t kZobrist[];    // DAT_1000de208
static NSDictionary *pieces;         // 棋子字符 -> pieceId

uint64_t getZobrist(char board[10][9], BOOL redGo, BOOL swap) {
    uint64_t key = 0;
    for (int row = 0; row < 10; row++) {
        for (int col = 0; col < 9; col++) {
            char c = board[row][col];
            if (c == ' ') continue;
            int pieceId = [pieces[@(c)] intValue];      // 0..31
            int cc = swap ? (8 - col) : col;            // 左右镜像
            int idx = kCoord[row * 9 + cc] + pieceId * 0x100;
            key ^= kZobrist[idx];
        }
    }
    if (redGo) key ^= 0xa0ce2af90c452f58ULL;            // 红先常量
    return key;
}
```

关键常量：

| 符号 | 地址 | 内容 |
|---|---|---|
| `DAT_1000de0a0` | file 0xde0a0 | 90 个 int32，值域 `0x33..0xCB`，每行 9 个、行距 0x10 |
| `DAT_1000de208` | file 0xde208 | 64 位随机数表，索引 = `coord + pieceId*0x100` |
| 红先 XOR | 立即数 | `0xa0ce2af90c452f58` |

格号编码（`kCoord` 实证）：

```
行 r = 0..9 → 高 4 位 0x3 + r
列 c = 0..8 → 低 4 位 0x3 + c
格号 = ((0x3 + r) << 4) | (0x3 + c)
```

所以 `0x33`（左上）到 `0xCB`（右下），中间行距 16、列距 1。

## 3. vmove 解码

方法：`ZobristUtils::getMoveFromVmove:leftRightSwap:` @ `0x100086744`

```c
// vmove = (from << 8) | to，from / to 均为上面的格号
uint8_t from = (vmove >> 8) & 0xFF;
uint8_t to   = vmove & 0xFF;
if (swap) {
    to   = (0x0E - (to   & 0x0F)) | (to   & 0xF0);
    from = (0x0E - (from & 0x0F)) | (from & 0xF0);
}
// 然后查 coordMap（格号 -> 坐标字符串）
```

`0x0E - col` 即左右镜像：列 3 ↔ B(11)。

## 4. 已导出的数据

- `docs/zobrist_table.bin`：`DAT_1000de208` 起 65,536 字节（8192 个 uint64）
- `docs/coord_map.bin`：`DAT_1000de0a0` 起 90 个 int32

## 5. 尚未闭环的一步

`pieces` 字典（棋子字符 → pieceId）没有从二进制里直接读出来，它是 `init` 里对 `0x10011c408` 的 `mutableCopy` 结果，属于 __DATA 中的常量对象，不是明文表。

但 id 空间是 `pieceId * 0x100`，说明 id 只占低 8 位，范围 0..31。棋盘上有 14 种棋子（红黑各 7），所以只需要校准 14 个映射。

校准方法：拿初始局面（`rnbakabnr/9/1c5c1/...`）算出 key，在 `bhobk` 里按 `vindex` 最小或 `vscore` 最高的行做匹配，遍历 id 排列即可锁定。一旦锁定，`OpeningBook` 就能从"统计展示"升级为真正的局面查表。
