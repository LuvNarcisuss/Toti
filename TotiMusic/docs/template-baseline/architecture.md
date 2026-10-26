# 架构、数据与平台约束

## 工程基线

- 源目录 `Teto/`；工程 `Teto.xcodeproj`；target/scheme/executable `teto`；显示名Teto；Bundle ID `com.teto.dance`；Swift语言模式5.0；最低iOS16.0。
- `project.yml` 是配置源。当前定义为iPhone、禁Mac Catalyst；纵向/左右横向，UIRequiresFullScreen=true。历史签名产物曾含iPad不等于本模板新增平板产品要求。
- UIKit程序化UI、UIViewController/UINavigationController、Auto Layout；Combine观察AppStore；AVFoundation播放与摄像头；PhotosUI单选导入；StoreKit1支付；WebKit协议。无需第三方SDK或后端即可提供已记录的本地功能。
- 禁止SwiftUI/SwiftUI Preview/UIHostingController/Objective-C源代码；不要机械复制Nana源码、域名、账号、商品或签名。
- 模板去掉原签名团队，未带CI发布配置，避免另一App被绑定原账号；不是已签名IPA。Xcode元数据可生成，不可把生成元数据叫构建。

## 启动与状态归属

`TetoAppDelegate → TetoSceneDelegate → TetoCoordinator → EntryController → TetoTabController`。窗口在加载前提供真实非空root，背景铺满window。加载完成与协议接受分开；账户退出由revision驱动重建入口。

`AppStore`为MainActor业务中枢，持有LocalLibrary、ShortsInteractionStore、WalletStore和VideoViewingHistory。UIKit订阅Combine而非每次渲染新建store。业务保存集中到actor repository；UI成功状态在持久化成功之后发布。状态刷新不要重建正在输入的举报表单或播放实例。

每个Tab独立导航栈；页面作为child controller正确addChild/didMove/willMove/removeFromParent。底部dock、评论overlay、全屏present分别管理。不把popover/子视图误当新的root，也不在视图未共享祖先前激活跨视图约束（之前启动插画崩溃根因）。

## 身份与模型

| 模型/键 | 必须保持的含义 |
|---|---|
| LocalVideo.id UUID | 全入口稳定视频身份，不从列表位置或标题生成 |
| DanceVideo.surface | Live或Shorts唯一场景；模板39条，两个流互不复用同一catalog条目 |
| LocalVideo.isDance: Bool? | nil是旧未分类私人视频；true仅分类声明，不等于内容审核 |
| creatorID | 内置沿用`pexels:<creator>`；私人作者`local-owner`；别按照片主体推断真实账号 |
| CreatorLocalState | follow、作者草稿、作者会话记录；可选以兼容旧库 |
| ChatLocalState | read/unread、pin/mute、hidden、drafts、sentMessages、followingOverrides、followerIDs、groups等现有字段 |
| creator-chat:<creatorID> | 同一个作者跨入口唯一会话，未知入向关系false |
| ContentSafetyTarget | kind+contentID确定内容；creatorID定位屏蔽目标；昵称不能作为视频/房间作者身份替代 |
| CreationSubmission | live/shortVideo，awaitingSubmission；只有真实服务才能推进状态 |
| WalletLedger | diamonds、activity、creditedTransactionIDs；schemaVersion1，交易幂等 |
| savedDemoVideoIDs | 旧收藏序列化键必须保留，虽然名字含禁用词，但不进入UI |

App内内置小统计使用固定ID散列作为编辑基数，重开一致；不在每次刷新调用random造成漂移。不冒充真实在线数、真人账号粉丝或来源平台统计。作者Likes/Saves从作品实时读取共享计数求和。本人Following由实际本地关注集合计算，Followers无来源为0。

## 本地存储

默认 `Application Support/Teto/`，数据保护 `completeUntilFirstUserAuthentication`，JSON原子写入。

| 文件/目录 | 内容 |
|---|---|
| library-v1.json | 个人资料、导入视频、收藏IDs、房间草稿、聊天/作者/安全/协议/提交等 |
| shorts-interactions-v1.json | liked、comments及回复关系、completedShares、legacy bonusLikes、独立liveLikes |
| video-viewing-history.json | UUID→最近观看时间，最多2000项，独立actor减少与个人资料保存竞争 |
| wallet-v1.json | 钻石余额/消费购买记录/已入账交易集合 |
| Media/UUID.ext、UUID.jpg | App自有导入媒体/封面/提交封面 |
| Media/profile-avatar.jpg | 个人照片，替换时使用next临时文件与保存顺序保证失败恢复 |

缺文件可初始化空值；解析失败、版本不支持、重复ID/非法关系/账本非法时保留原件并阻止写入，不能静默reset。观看历史损坏仅影响推荐时，不得顺手删除其他数据。

相同沙盒里迁移旧App目录：只有唯一、可读、格式匹配的旧library候选才整体move目录；多个候选或不可读则停止。不同Bundle ID是不同容器，不承诺自动跨ID迁移。

导入：系统提供者临时URL有效期间复制；检查视频轨道、时长、大小；先写媒体，再保存library；失败仅清理这次新副本。孤儿清理仅在成功读取library后、仅App自有Media、仅符合UUID文件和允许扩展名；保留头像临时文件以及旧私人功能仍引用的文件。不能扫描/删除相册、用户原资料库、任意Design原片。

模板为不破坏旧库保留只读旧Phrases模型/目录校验数据和媒体引用保护。没有创建/练习业务、影片或页面。不可因“不要Phrases”去抹掉用户已有私人JSON字段、报告或媒体；已存在旧举报可从Settings移除而不恢复旧功能入口。

## 文本和输入校验

应用默认en：`developmentLanguage: en`、CFBundleDevelopmentRegion、CFBundleLocalizations=['en']，英文权限说明。系统键盘、Photos、分享面板由设备语言决定，不宣称完全控制。

`CreationValidation.isEnglish`目前拒绝非ASCII字母，允许数字/标点等；它不是语言识别模型，也不能证明用户写的是英语。新增输入需在UI和保存边界沿用/补齐校验，错误文案英文。保留旧私人数据，不后台改写/删除。新服务数据要明确校验/过滤规则，不能当默认合格内容直接渲染。

| 输入 | 限制 |
|---|---|
| Profile name / biography | 30 / 160字符 |
| 创建Title / caption | 标题非空≤80 / 介绍≤500 |
| Voice party title / description | 标题非空≤60 / ≤240；人数4/6/8 |
| Live输入 / Shorts弹幕 | 50 / 80英文字符 |
| 普通视频评论 / Voice行 | 200英文字符；持久Shorts每视频500条 |
| 单聊消息/草稿 | 2000字符；发送时再次检查关系和英文 |
| 举报详情 | 500字符 |
| 短视频新提交 | ≤180秒、≤250MB |
| 旧个人视频导入底层能力 | ≤30分钟、≤250MB；不要把它误用于新的Shorts提交 |
| 图片导入 | ≤30MB，可解码；降采样后保留比例 |

## 媒体生命周期

视频由稳定对象拥有AVPlayer和observer；视频画面使用resizeAspectFill，默认1×，不改原始时间戳。Live、Shorts、卡片三个播放生命周期不能混为一谈：Live覆盖可继续，Shorts覆盖暂停，卡片只播首秒且只在可见时。离开/后台/失败停止任务，取消回调不能启动已经离开的播放器；多个入口不可后台叠音。

弹幕、爱心、语音说话条与视频相互独立；布局或评论更新不会重置播放。长列表用table/可见卡资源管理；无穷历史上限明确。Reduce Motion减掉持续漂移/弹簧；VoiceOver按钮有英文label/value及替代操作。

摄像头只在视频通话画面或Scan入口按用户动作申请；没有麦克风采集，不增加假用途的麦克风权限。Photos使用PHPicker不申请整库读权限。视频通话前后切换、授权错误、interrupt、后台恢复和iOS16方向fallback均保留。

## 未来服务接入

要接真实服务时，在现有state/repository边界加适配层：身份/资料、分页feed、live播放与推流、RTC房间、IM/关系图、审核/举报、钱包验证。服务器权威执行关系限制、审核状态与余额；迁移策略显式设计。用户当前只要等价本地应用时，不自行创建云账号、虚构host、提交审核或启动CI。
