# 本包静态核对记录

日期：2026-10-23。只做文件、源码、配置、资源引用及归档完整性检查；未编译、类型检查、运行 App、启动模拟器或执行应用测试。未对全部素材重新逐帧审核，来源视觉证据沿用项目登记。

- 逐页读取13个历史Codex会话，共164回合/151条用户消息，并补读内购ChatGPT会话；部分附件不可恢复，见session-index。
- 独立只读审查发现移除Phrases时误删相邻Live目录条目，已从原源码恢复dance-mosaic-steps，重新核对最终集合。
- 四Tab布局等分、拖动索引、控制器路由静态一致。Phrases控制器/业务扩展/聊天打开动作/七段影片不在模板；旧私人数据兼容模型保留。
- 39条目录（Live22/Shorts17）、39段MP4、39张JPG、39条SourceMedia记录逐项一致；UUID及assetName无重复。
- 43个Swift源文件；未发现SwiftUI、UIHostingController、Objective-C或对已删除控制器/业务方法的残留引用。
- 198个资源目录Contents.json中的文件引用存在；JSON、plist、scheme/workspace XML可解析；Python脚本通过AST语法解析；skill本地Markdown链接存在。
- XcodeGen已在暂存副本成功生成工程元数据；不是构建。scheme已随包保存，无签名团队/CI发布配置；已排除嵌套.git与工作区用户元数据。
- skill-creator自带quick_validate.py因当前Python缺少PyYAML不能运行；替代用Ruby YAML解析SKILL frontmatter、agents/openai.yaml和project.yml，核对name/description类型及长度。本记录不把替代检查称为原验证器通过。
- 模板ZIP与逐文件SHA-256由instantiate.py --inspect进行静态校验；该模式不解包、联网、编译或运行App。未执行新目录创建后的运行验收。

原项目已有Teto.xcodeproj/project.pbxproj改动及Teto/.gitattributes保留。本次只新增Skills产物；模板变化未反写应用源码。
