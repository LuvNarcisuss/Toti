# 源码定位与复用顺序

所有路径相对于解包工程；不依赖 `/Users/apple/Desktop/Teto`。

| 需求 | 首读源码 |
|---|---|
| 启动、协议UI、四Tab、dock生命周期 | Teto/App/TetoApplication.swift |
| 共用业务与持久化操作 | Teto/App/AppStore.swift |
| 主题、按钮、弹窗、气泡选择、搜索、分享、头像拼图 | Teto/DesignSystem/TetoUIKit.swift |
| 位图图标枚举/品牌 | Teto/DesignSystem/TetoIcons.swift |
| 真人照片分配 | Teto/DesignSystem/FreshStudioPhotos.swift；Teto/Domain/DancerPortraits.swift |
| Live/Shorts目录与稳定ID | Teto/Domain/DanceVideoCatalog.swift |
| 推荐重排与观看记录 | Teto/Domain/VideoRecommendations.swift；Teto/Data/VideoViewingHistory.swift |
| Live发现、卡片首秒视频 | Teto/Features/Live/VideoDiscoveryController.swift |
| 当前Live/Shorts房间、手势、弹幕、分享、评论overlay | Teto/Features/Shorts/VideoFeedController.swift |
| 播放器 | Teto/Platform/Media/LocalVideoPlayback.swift；LiveRoomPlayback.swift；ShortsPlayback.swift |
| Live类型/152条英文词条 | Teto/Features/LiveRoom/LiveRoomModels.swift |
| 旧LiveRoomStore接口 | Teto/Features/LiveRoom/LiveRoomStore.swift；不是当前UIKit直播气泡调度入口 |
| 小统计、点赞/评论/回复、分享、Live迁移 | Teto/Features/Shorts/ShortsInteractionStore.swift |
| 独立互动文件 | Teto/Data/ShortsInteractionRepository.swift |
| 每片讨论编写内容 | Teto/Domain/DanceDiscussionContent.swift |
| 创建两个表单、待提交状态 | Teto/Features/Creation/CreationController.swift；CreationSubmission.swift |
| Voice列表/卡片/席位/消息/邀请/创建 | Teto/Features/Parties/PartyControllers.swift |
| Voice房间、分类、8个成员名单 | Teto/Features/Parties/PartyModels.swift；PartyDiscoveryStore.swift |
| Voice循环词条 | Teto/Features/Parties/VoiceRoomChatScript.swift |
| Chats列表滑动操作、搜索、好友、群、扫码、对话 | Teto/Features/Chats/ChatControllers.swift |
| Chats编写历史、关系、持久模型 | Teto/Features/Chats/ChatModels.swift |
| 作者身份与本地统计基础 | Teto/Features/Creators/CreatorProfile.swift |
| Me、作者主页、资料编辑、设置、举报/拉黑列表 | Teto/Features/Profile/ProfileControllers.swift |
| Comments、举报表单、Wallet UI、Gifts UI/动画 | Teto/Features/Community/CommunityControllers.swift |
| 举报类别/报告/屏蔽模型 | Teto/Features/Safety/ContentSafety.swift |
| Call页面与摄像头生命周期 | Teto/Features/Calls/CallController.swift；CallCameraController.swift；CallCameraSurface.swift |
| 交易、价格、幂等入账/扣账 | Teto/Features/Wallet/StoreKit1Purchasing.swift；WalletStore.swift；WalletModels.swift |
| library快照和原子仓储 | Teto/Domain/LocalLibrary.swift；Teto/Data/LocalLibraryRepository.swift |
| 协议模型/哈希、离线文件 | Teto/Features/Authentication/UserAgreement.swift；Agreements/ |
| 工程元数据/英文语言/权限 | project.yml；Teto/Support/Info.plist；Teto.xcodeproj/xcshareddata/xcschemes/teto.xcscheme |

## 新建工程的完成顺序

先从附带模板落地可查看文件，然后核对规格而不是重做MVP。需要移植时按：入口/设计系统/数据 → Live列表到房间 → Shorts及共享互动 → Voice列表到房间 → Chats及关系 → 作者与Me → 创建/安全 → 钱包/协议/权限。状态模型先定，避免每页各自存Likes、关系或草稿。

## 关键跨入口调用链

- 点赞：VideoFeedController分live/shorts → addLiveLike/toggleLike → ShortsInteractionRepository → 通知AppStore/Me/作者页。
- 收藏：toggleSaved → LocalLibraryRepository → savedVideos及counts(for:)的isSaved。
- 私信：creatorID映射canonical conversation → openCreatorConversation → ConversationController → canSendChatMessage → sendChatMessage原子commit。
- 分享：showContentShare → sendChatMessage 或复制地址 → Shorts成功计数 → ConversationController校验sharedVideo再打开。
- 创建：CreationController → queueCreation →导入视频/封面 → submissions.awaitingSubmission → Me Pending review。
- 举报：SafetyController → saveContentReport →保存成功回调关闭/刷新 → filters隐藏 → Settings移除报告恢复。
- 充值：WalletController → WalletStore → StoreKit1Purchasing →持久闭包repository.saveWallet →finishTransaction。
- 礼物：GiftsController → WalletStore.send → spend →同一wallet原子保存 → GiftBurst；不是网络gift服务。

## 模板与源项目差异

本次只调整模板副本：5改4Tab与气泡尺寸/索引；删除Phrases控制器/扩展业务/作者列表/聊天动作/7段视频和catalog条目；保留旧资料解码；删除无交易模拟器钻石注入；不带签名团队/CI账号。`template-changes.patch`记录主要文本差异，manifest记录最终完整文件集。应用其余模块按当前源码快照复用。源项目已有修改保持不动。
