# 会员与自动走子（静态结论）

## 会员校验

主二进制里与内购相关的符号（Swift mangled 已还原可读部分）：

```
ReceiptValidator (service:sharedSecret:)
ReceiptID:success:failure: / ReceiptID:task:
Purchase9productId9inReceipt...
Receipt10validUntilAA24VerifySubscriptionResult
PurchaseNoticeController
PayWeekButton / PayYearButton / PayLifetimeButton
PaySuccess / PayWeek* / PayYear* / PayLifetime*
```

结构：**StoreKit 1（app receipt）+ 自建 `ReceiptValidator` 服务端校验**，三档（周 / 年 / 终身），另有周/年/终身 × 普通/Pro/Super 的价格按钮，说明是按引擎等级分档。

没有看到 StoreKit 2 的 `Transaction.currentEntitlements` 相关符号，也没有本地公钥验签逻辑 —— 校验完全在服务端。

## 自动走子

全二进制搜 `autoPlay` / `autoMove` / `autoTap` / `CGEvent` / `IOHID` / `sendEvent` / `assistive`，只命中一个 `simulat` 片段，没有触摸注入、没有辅助功能 API、没有私有 HID 调用。

结合 iOS 沙盒限制，作者做不到跨 App 自动点击。海报上的「自动走子」在 iOS 上要么是：

1. 对着自家演示棋盘（`demoBoardWithScale:`）自动落子，不是对手 App；
2. 用 Broadcast 扩展只做「画中画显示」，落地仍需用户手动点；
3. 夸大宣传。

这也是我们复刻只做「建议 + 画中画」的原因：iOS 侧没有合法路径把触摸送进别的 App。
