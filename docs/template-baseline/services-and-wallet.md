# 服务边界、钱包、礼物与发布配置

## 能力逐项分清

| 能力 | 此模板实际提供 | 不能宣称 |
|---|---|---|
| 登录 | 协议确认后打开本地库 | 在线认证/手机号校验/真实账户token |
| Live | 本地录制舞蹈影片沉浸播放、房间交互 | 实时推流/真实主播在线 |
| Shorts | 本地舞蹈流、互动、本地待提交 | 公共上传/服务端推荐/审核通过 |
| Voice | 编写房间/成员、当地消息、静音与说话动画 | RTC音频连接/真人正在说话 |
| Chats | 内置历史+原子本地outbox、草稿、关注规则 | 送达/已读、跨设备同步、远端自动回复 |
| Calls | 语音布局；本机摄像头/翻转 | 语音采集、远端连接、录像或上传 |
| Scan | 真摄像头QR→本地ID匹配 | 网络好友检索/附近匹配 |
| 举报 | 本机记录、隐藏、可撤销 | 已交平台人工审核/用户已封禁 |
| 充值 | StoreKit1商品请求、交易回调、幂等本地入账 | 商品已在当前商店注册/线上交易已成功验证 |
| 礼物 | 有余额时本地扣账+记录+效果，失败不扣 | 主播到账、服务端礼物投递、指定成员实际收礼 |
| 分享 | 本机消息和复制内部URL | 公网可访问/跨设备媒体传输 |

真实加载/错误/权限拒绝不能为了“真实感”删除。产品不出现展示标签，也不以伪造成功替代没接的功能。UI层的“Saved”“Pending”“Waiting to submit”应对应确实完成的本地操作。

## 九档钻石

钱包在Me入口。唯一余额Diamonds，3×3网格，实际价格使用StoreKit返回的localized price；未加载显示See price。选择档位后确认，Continue等待商品返回再发起SKPayment。以下USD仅参考，不是对用户的最终收费承诺。

| 钻石 | 参考USD | 当前Teto商品ID |
|---:|---:|---|
| 400 | 0.99 | hoewtkchclzkuruf |
| 800 | 1.99 | qbfuucwaccetjljs |
| 2,450 | 4.99 | mdnrsibqccschjcg |
| 5,150 | 9.99 | olfouxazhsdntxzs |
| 10,800 | 19.99 | ejtvapyfnomaimlf |
| 16,800 | 29.99 | mwkqplvxbtdrjcsn |
| 29,400 | 49.99 | uficsdpshzadegnz |
| 42,600 | 69.99 | hycnfrwzqmkplvtd |
| 63,700 | 99.99 | cbhpozbwbvfwgqxp |

只复刻这个用户的同一Teto身份才保留这些ID；新App必须确认对应Bundle ID商店目录，不能生成看似有效的16位字符串当注册成功。旧qlrpflukqugckska/zhkxxppfqwqfwhcp不再使用。外部“Tati Coins”的格式例子不是Teto需求。

交易流程：SKProductsRequest → SKProduct → SKPaymentQueue。仅purchased/restored且属于目录的交易候选可入账；transactionIdentifier及关联原交易ID防重。原子保存wallet成功后才finishTransaction。失败保留unfinished供下次重试；取消、不存在的产品、失败不加钻石。deferred等待批准，不能finish或提示成功。并发购买busy保护，余额非负，乘法/加法溢出防护。不存在恢复消耗型商品的独立Restore按钮。

Activity记录真实本地账本操作；空时No transactions yet。退出登录保留钱包；删除本机账号删wallet文件，尚未完成的商店交易仍可能后续回调，不能承诺清除Apple交易。本模板无模拟器赠400钻石，没有无交易起始信用。

## 礼物

| 礼物 | 单价钻石 |
|---|---:|
| Rose | 10 |
| Balloons | 50 |
| Heart | 100 |
| Beat Drop | 200 |
| Spotlight | 500 |
| Bouquet | 1,000 |
| Dance Crown | 2,000 |
| Encore | 5,000 |
| Dance Galaxy | 10,000 |

网格3列，透明位图图案；显示余额和Add more通往Wallet；数量UI为1/5/10，业务校验范围1–99。每项价格=单价×数量，余额不足原样返回，不显示礼物成功动画。余额足够→保存扣账和kind=gift记录→发布新余额→播放非阻塞全屏礼物图案/卫星图案/名称数量，结束移除。Reduce Motion缩减动画。活动展示最多40条，不丢交易去重集合。

Live和Voice都可用；Voice有Everyone/成员选择，但目前没有接收人ID传到spend服务，属于尚未接通的目标选择。不得把这一点写成多方分账或远端收礼。UI接入后端时必须携带目标并设计服务器事务，不能在已有本地扣账之外又重复扣款。

钱包须写明钻石用于房间礼物；普通消息、评论和弹幕免费。不得增加金币、聊天收费、AI付费聊天或其它任意消耗场景。

## 协议

本地 `Agreements/TermsOfService.html`、`PrivacyPolicy.html` 保留；Teto联系人 `18781461148@163.com`。现有线上地址：

- Terms：https://docs.google.com/document/d/1PBHnF3UNjCBkEuzOyETCUOWgMEz4eiPfGj_PooGJM4c
- Privacy：https://docs.google.com/document/d/1BGNLMpwOFa8_6Fz3S4zv9xkKELYTBEx3KXi3DLVBSj0

这是会话确认过的文档ID，不是本次重新验证的公开链接。上次记录仍owner-only，未确认anonymous读取；不要说已公开。AgreementController使用非持久WKWebView，限制主框架导航到对应文档；HTTP错误、网络失败、Google登录跳转回退本地，显示Saved copy。HTTP200权限拦截页目前不一定被检测。新品牌必须替换自己合法持有的协议与联系方式，不能继承原服务责任描述。

## 打包/发布：仅在用户明确请求时

原Teto工作流信息：Xcode26.5、App Store Connect集成名Teto、Apple App ID6826151569、Bundle ID com.teto.dance、项目根目录Teto.xcodeproj/teto。Git LFS存视频，必须拉取真实文件而非指针；共享scheme要加入Git，不能被全局`*.xcscheme`忽略。

Codemagic流程若用户需要：校验工程/scheme/BundleID → 拉LFS → 账号已有distribution证书/profile → 查跨版本最高TestFlight build number，取下一个/CI较大值 → archive/export → publishing.app_store_connect.auth: integration上传。查询认证失败则停，不默默回退重复build number。自动beta review和App Store review默认false；不要凭之前的上传授权自动触发本次发布。

模板没有带原人的邮件通知收件人、签名证书、密钥、Git remote或CI凭据。从skill生成工程不等于打包/上传/审核；未经用户明确要求仍不得编译或跑云构建。
