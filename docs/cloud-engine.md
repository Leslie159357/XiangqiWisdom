# 云引擎协议（静态还原 + 实测）

对象：`com.su.chessaihelper` v66，方法 `ChessEngine::callCloudEngineBan:` @ `0x100081f24`。

## 1. 端点

| 用途 | URL |
|---|---|
| 主站 | `https://engine.chessbots.cn/run` |
| 阿里云 FC 备用 | `https://enginec-cchess-rcxpfgfxak.cn-hangzhou.fcapp.run` |
| 云端开局库 | `http://www.chessdb.cn/chessdb.php?action=queryall&board=...` |

`ChessEngine.type` 为 4 时走 FC 端点，否则走主站。

## 2. 请求

方法：**GET**（`PDNetworking` 把参数字典拼到 query）。

参数（5 个）：

| 键 | 来源 |
|---|---|
| `fen` | 当前局面 FEN |
| `time` | `thinkTime`（秒，double 转字符串） |
| `pv` | multipv 档位（整数转字符串） |
| `auth` | SHA256 hex |
| `ban` | 禁手列表（可空） |

请求头：

```
Authorization: Bearer token-7cecb6dzd9dc769811dcb6eh5hdc3986a9kdei69e1a   (主站)
Authorization: Bearer token-4e7fba8gfac34fa8fbjfj0bj5ha0                 (FC 备用)
```

## 3. 签名

```objc
NSString *s = [NSString stringWithFormat:@"%@swdwy", [self fen]];
uint8_t digest[32];
CC_SHA256(s.UTF8String, strlen(s.UTF8String), digest);
// 逐字节 %02x 拼成 64 字符 hex
```

即 `auth = SHA256(fen + "swdwy")` 的 hex。

## 4. 实测结果

用上述公式和硬编码 token 直连主站：

```
GET https://engine.chessbots.cn/run?fen=...&time=1&pv=3&auth=<sha256>&ban=
Authorization: Bearer token-7cecb6dz...
→ HTTP 403  body: signaturenotmatch
```

已排除的变量：

- 换 FEN 格式（完整 / 到 `w` 为止）→ 403
- 换 `time` 为整数 `1` → 403
- 加 CFNetwork User-Agent → 403

结论：**协议结构是完整的，但服务端当前不接受这组签名**。三种可能：

1. App 发布后 token 被轮换，二进制里这两个是旧值；
2. 签名还缺一个隐藏参数（静态伪代码里被优化掉的寄存器）；
3. 服务端另有设备/IP 维度校验。

要确认只能靠真机抓包：在旧版 App 上跑一次云引擎请求，抓 `engine.chessbots.cn/run` 的完整 URL 和 `Authorization` 头，与二进制里的公式逐字节比对。

## 5. 附带发现

- 云端开局库走 `chessdb.cn` 的 `queryall`，无签名，纯 GET
- 二进制里有 Bark 推送地址 `api.day.app/ebUPVCdyLy4KtsbgyJdgxh/`，是作者自用的告警通道
- `PDNetworking` 是自研网络层，超时 3s/5s 两档
