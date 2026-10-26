# 交付检查与已知边界

默认只有静态检查：读取文件、解析JSON/plist/XML、对照源码和引用、核对hash、检查配置。不要执行xcodebuild、swiftc/typecheck、App、Simulator、Preview、单元/集成/UI测试。XcodeGen生成元数据不等于构建。

## 静态交付清单

- [ ] SKILL/frontmatter及引用存在；模板zip校验SHA-256，逐文件manifest一致；没有LFS指针替代视频。
- [ ] Live/Voice/Chats/Me四Tab；Shorts属于Live；dock所有等分/边界为4；没有Phrases页面、个人入口或Open phrase聊天动作。
- [ ] iOS16、Swift5、UIKit/AVFoundation；没有SwiftUI/Hosting/OC源码；project.yml与pbxproj一致。
- [ ] 按媒体清单找到39段舞蹈视频和39张匹配封面；Live/Shorts的ID/asset/surface唯一；没有Phrases影片或非舞蹈视频。
- [ ] 新增文案、默认数据、权限/无障碍、协议品牌和资源可见文字符合英文/禁用词规范；源码系统API名和兼容字段人工判定不误删。
- [ ] Live是列表→房间、首秒卡片循环、全屏1×循环、无进度条；Shorts是视频流及独立暂停/评论/分享流程。
- [ ] 当前UIKitLive评论1–3/s、50字符、最多7框；Shorts1–5/s、96pt/s、80字符；Voice1–2秒1–3条、200历史上限。
- [ ] 点赞/收藏/评论/回复跨Shorts、收藏、作者、Me共用稳定视频ID；Live点赞不进入Liked；Like count与Liked列表数量同源。
- [ ] 回复目标/草稿失败保留；举报只隐藏目标；点击保存失败不虚假成功；列表刷新不重建player。
- [ ] Live/Shorts/Voice分享好友+复制内部URL；本机视频消息打开再次校验surface、分类、屏蔽和待提交；不宣称公开链接。
- [ ] 互关无限本地消息、非互关一条、群豁免、activity只读、屏蔽禁发；主页未互关隐藏Message；已有会话保留。
- [ ] 群聊成员照片拼图；单人头像一致且无不同人物撞图；Voice内置成员不跨房重复。
- [ ] 新建Live/Shorts先表单再媒体、待提交在Me，短视频3min/250MB；无假开播/审核通过。
- [ ] Settings包含Edit profile、双协议、Blocked、Reported、Log out、Delete account；毁损文件不覆盖，Photos原件不删。
- [ ] 9档StoreKit价格与ID一致；本地ledger初始0、交易幂等、保存后finish；礼物不足不扣、成功只本地扣账+效果；无金币或聊天扣费。
- [ ] 摄像头仅视频页/扫码；iOS16方向fallback、拒绝重试、退出后台停止；无远端RTC/IM或麦克风采集伪实现。
- [ ] 协议默认不勾，点击链接不接受，保存后进入；线上地址不可用能本地回退，不能宣称旧私有链接已公开。
- [ ] 字体、Logo、透明图标、资源/源文件工程引用完整；共享scheme已在包内，无签名凭据和个人CI通知账号。
- [ ] 最终交付区分源码实现、静态证据、缺失服务、尚未运行验证；不声称能直接上线。

## 已知现状不能掩盖

1. 无后端：实时直播推流、RTC、IM网络送达、在线关系/资料、公共发布、服务端审核和举报不存在。
2. StoreKit代码存在，但当前BundleID下商品可用性、签名、真钱交易、账本故障恢复未运行验证。
3. Voice目标选择没有进入礼物账本/远端服务；Voice分享文本没有和Live/Shorts相同的聊天解析打开按钮。
4. 通话按钮只是当前单聊的页面入口，源码没有额外互关鉴权；不能把Tati格式示例的“互关才通话”错误移植为Teto现有行为。
5. 本地英文校验是字符范围判断，不是语义识别；导入舞蹈确认是用户声明，不是自动视觉审核。
6. 历史协议Google文档仍需确认公开访问，HTTP200权限阻断可能绕过fallback检测。
7. 静态资源和历史代表帧审查不等于本次逐帧复核；没有实测模板的布局、播放、手势、摄像头、动态字号或内存性能。
8. 模板移除Phrases后的四Tab分支只经过静态源引用/资源检查；未经编译或设备运行验证。

## 获得明确运行授权后才做的验收场景

在用户选定的设备/Simulator中按完整路径验证：首次协议/断网回退/坏库；Live卡→房间→主页→返回与后台；Shorts评论回复/分享/收藏/快速点赞/退出重开；Voice席位/输入/引用/邀请；好友一条限制与互关/取消关注；群聊拼图/扫码拒绝；举报隐藏再撤销；照片取消/失败；StoreKit成功/取消/deferred/重复交易/保存失败；删除账号/Photos原件保留。记录真实结果，不以执行过命令代替通过。
