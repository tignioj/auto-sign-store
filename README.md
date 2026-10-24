# AutoSign Store

原生 SwiftUI iPhone / iPad 客户端，通过同一局域网中的 [AutoSign](https://github.com/tignioj/auto-sign) Mac 安装、更新及续签应用，包括 AutoSign Store 自身。支持在手机管理应用源、浏览应用，并让 Mac 自动下载、签名及安装。

## 语言 / Languages

支持 **简体中文和 English**，默认跟随系统语言。可在 **连接 → 语言** 中选择“跟随系统”、English 或简体中文，立即生效并保存在本机。未支持的系统语言回退到英文。日期、文件大小和应用数量随所选语言格式化。

Supports **English and Simplified Chinese**, following the system language by default. Choose **Connection → Language** to switch immediately; your preference is saved on this device. Unsupported system languages fall back to English. Dates, file sizes, and app counts use the selected locale.

界面、客户端错误及本地网络权限说明均已本地化。Mac 返回的任务日志、错误详情以及第三方源提供的应用名称、介绍和更新说明保留原文；客户端发送 `Accept-Language`，供支持该请求头的服务端返回对应语言。

翻译资源位于 `AutoSignStore/Core/Resources/{en,zh-Hans}.lproj/`，数量文案使用 `Localizable.stringsdict`；系统权限说明位于 `AutoSignStore/Resources/{en,zh-Hans}.lproj/InfoPlist.strings`。新增文案请同时补全两种语言，通过 `L10n.tr` 调用，再运行 `swift test` 检查资源覆盖与格式参数。重新生成 Xcode 工程会自动保留本地化资源。

## 使用要求

- iPhone / iPad：iOS / iPadOS 17 或更高版本。
- Mac：macOS 14 或更高版本，安装完整 Xcode 并登录有效的 Apple 账号，运行 AutoSign。
- 首次使用通过 USB 信任并配对设备，开启开发者模式；无线使用时在 Finder 启用“连接到 Wi-Fi 时显示此设备”。手机与 Mac 需处于可互访的同一局域网。

各功能的最低版本要求如下，建议两端均使用最新版：

| 功能 | Store | Mac AutoSign |
| --- | --- | --- |
| 手机源管理与安装 | 1.1.0 | 1.3.0 |
| 源更新检测与一键更新 | 1.2.0 | 1.4.0 |
| 优先仅更新描述文件续签 | 兼容旧客户端，界面说明需 1.2.0 | 1.4.1 |

## 首次安装与连接

1. 按 [Mac 端构建与运行说明](https://github.com/tignioj/auto-sign#构建和运行) 启动 AutoSign，完成 USB 配对、开发者模式及 Xcode 账号配置，在“签名设置”选择证书和描述文件。
2. 在 Mac 的“应用源”点击 **添加 AutoSign Store 源**，或手动添加以下固定地址。

   ```text
   https://raw.githubusercontent.com/tignioj/auto-sign-store/source/apps.json
   ```

3. 在 Mac 的“安装应用”选择目标设备，勾选 AutoSign Store，点击 **安装所选应用**。源中的 IPA 是未签名真机包，由 Mac 使用你自己的开发者身份签名。首次安装后，根据系统提示信任开发者证书。
4. 在 Mac 的“手机连接”开启局域网服务。
5. 手机打开 Store 的“连接”，允许本地网络权限，选择发现的 Mac，粘贴 Mac 显示的配对密钥并连接。发现失败时，可手动输入 `http://Mac的局域网IP:8091` 或 Mac 的 `.local` 地址。
6. 在“我的应用”明确选择这台手机 / 平板。iOS 不提供通用的本机 UDID 读取接口，需要核对设备名称。

连接或同步状态等待过久时，可在“连接”页点击 **取消连接**，立即恢复操作，再修改地址或重新连接。取消会停止本次请求并保留已保存的配对信息；改地址后需输入配对密钥并点击 **配对并连接**，成功后才保存新地址。

也可以从 [GitHub Releases](https://github.com/tignioj/auto-sign-store/releases) 下载 `AutoSignStore.ipa`。首次安装 Store 需要 Mac；安装后可在手机“应用源”安装 Store 新版，或在“我的应用”更新，由 Mac 完成下载及覆盖安装。

应用列表来自 AutoSign 的成功安装记录；未纳入管理的旧应用需用新版 AutoSign 覆盖安装一次。每个应用需要匹配自己 Bundle ID 的描述文件；复用同一个明确 Bundle ID 的描述文件签多个应用，会导致标识相同并互相覆盖。后续续签或升级需保持原应用标识和签名团队一致。

## 手机源管理与安装

1. 连接 Mac 后，在手机“应用源”点击 **添加源**，输入 AltStore / SideStore JSON 地址；可快捷填写 Kazumi 或 Store 源。
2. 打开源，搜索或浏览应用，查看版本、大小、系统要求和更新说明。在应用详情核对目标设备，点击 **安装到〈设备名称〉**。
3. 在“活动”查看检查源、下载、配置签名、安装及最终结果。成功后应用进入“我的应用”，以后可直接刷新签名。

源订阅与缓存保存在 Mac，与 Mac 的“应用源”共用。长按源可刷新或移除，左滑也可移除。源刷新失败保留原列表；手机离线显示上次同步内容。移除源不卸载应用，也不移除已安装应用的续签资料。

Mac 在安装前必须重新获取最新源，并检查下载大小、IPA 完整性和真实 Bundle ID。首次安装使用 Mac 选定的签名团队，为不同应用生成独立、稳定的团队专属标识，避免复用 Store 的标识或申请发布者已占用的标识。升级受管理应用时沿用原标识及团队，也能识别旧版手动安装时被改写标识的原始 IPA。源中最新版本始终取 `versions` 第一项；用户点安装后源有更新时，实际安装版本以任务结果为准。

手机退出、网络响应丢失或升级 Store 自身导致退出后，重新连接可恢复任务结果。服务重启会将未完成任务标记为中断，需要重新发起。

签名使用原有 Xcode 流程，免费账号须获得新的 7 天描述文件才继续安装。Apple 账号、设备配对和开发者模式仍需有效。包含现有签名器不支持的扩展或权限的 IPA 会明确报错；这些任务不会显示安装成功。

## 源更新检测与一键更新

开启 Mac 局域网服务后，默认每 30 分钟检查所有已订阅源，启动或休眠唤醒后若已到时间会补查；安装、下载忙碌时延后。Mac 必须保持 AutoSign 运行并联网，可在“手机连接”关闭自动检查。

手机“我的应用”显示更新徽标、版本变化及更新说明，可点击 **更新** 或 **一键更新全部**（每批最多 50 个）；**检查更新**立即让 Mac 检查所有远端源。手机前台空闲时每 30 秒自动同步，执行任务时每 2 秒查询进度，重开自动同步；手机完全关闭时没有系统推送。离线显示缓存，部分源失败保留上次结果并提示。

版本与构建号均参与比较，避免降级或重复升级。已关联的应用固定使用原源；旧记录从保存的 IPA 识别原标识与构建号，多个源都包含同一应用且没有关联时不自动选择。移除源后停止提示该源的更新。更新前重新获取源并验证 IPA 的真实版本、构建号及应用标识；覆盖安装沿用原应用标识与签名团队。批量任务逐项保存，部分失败不影响其他项，Store 自身最后更新，重开可恢复任务结果。签名刷新仍使用原 IPA。

## 续签与自身刷新

在“我的应用”点击 **刷新全部应用**，或点开应用详情进行单独刷新。批量刷新可选择是否包含 Store 自身，Store 始终最后处理。到期时间来自 Mac 最近成功验证的签名；离线时显示上次同步记录。

批量刷新只处理当前所选设备。“我的应用”和“活动”的任务进度按所选设备显示；其他设备有任务时会明确提示设备名称及刷新、安装或更新类型。Mac 串行处理任务，其他设备忙碌时暂不能提交新任务，但可以切换设备查看各自进度。

Mac 1.4.1 起优先单独安装新描述文件，读回设备文件并核对有效期延长、安装位置与版本不变，无需重装或退出 Store。不兼容时沿用原应用标识和签名团队重新签名、覆盖安装，此时 iOS 可能关闭 Store；Mac 仍继续执行，重新打开后可恢复结果。

是否验证应用启动遵循 Mac“自动续签”中的 **刷新签名后验证应用启动** 开关，默认关闭。开启时需解锁设备；关闭后仍校验新描述文件、有效期和安装结果。连接中断、设备锁定或校验失败不会被当作兼容性问题直接触发重装。Store 已掉签无法打开时，可从 Mac 续签；无法直接恢复时再覆盖安装。

这是**手机发起、Mac 获取并更新签名**的方案，自动续签由 Mac 后台任务执行，不依赖 iOS 定时唤醒。Mac 需要保持开机、联网并运行 AutoSign，Xcode 账号需要有效。免费账号续签成功后的有效期为新签发时间起 7 天；签发失败或返回旧文件时会报错。

缓存处理、描述文件校验及后台续签设置详见 [Mac 端说明](https://github.com/tignioj/auto-sign#操作)。

## 构建

需要支持 Swift 6 的完整 Xcode；最低 iOS / iPadOS 17。无第三方依赖。在本仓库根目录执行：

```sh
open AutoSignStore.xcodeproj
```

选择 `AutoSignStore` scheme 即可在模拟器运行。通过 Xcode 安装到真机时，在 Signing & Capabilities 选择自己的开发团队，使用唯一 Bundle ID。

生成供 AutoSign 签名的 **未签名 IPA**：

```sh
./Scripts/build-ipa.sh
```

输出 `dist/AutoSignStore.ipa`。这是 arm64 真机安装包，需要 AutoSign 签名后才能安装；模拟器包不能在真机运行。

工程文件已提交，不依赖 XcodeGen。新增 Swift 文件后可重新生成工程；生成器会覆盖工程配置，临时设置的开发团队或 Bundle ID 需重新选择，长期修改应同步到生成器：

```sh
python3 Scripts/generate-project.py
```

## GitHub 自动构建与发布

向 `main` 推送、提交 Pull Request 或在 Actions 手动运行 **Build and publish**，都会执行 Swift 核心测试、源生成测试，构建未签名真机 IPA，并上传 IPA 和 SHA-256 校验文件作为 Actions artifact。仅 `v` 开头的标签触发发布，普通分支构建不改变公开源。

发布正式版本时，在 `Scripts/generate-project.py` 中更新 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`，重新生成工程，提交并推送 `main`，再推送匹配版本的标签。以下 `X.Y.Z` 替换为实际新版本号：

```sh
version=X.Y.Z
python3 Scripts/generate-project.py
git add Scripts/generate-project.py AutoSignStore.xcodeproj
git commit -m "Release $version"
git push origin main
git tag "v$version"
git push origin "v$version"
```

`vX.Y.Z` 标签必须属于 `main`，并与实际 IPA 的版本完全匹配。构建成功后，Actions 使用仓库自带的 `GITHUB_TOKEN`：

1. 将 `AutoSignStore.ipa` 及 SHA-256 校验文件发布到该标签的 GitHub Release。
2. 从实际 IPA 读取 Bundle ID、版本、构建号、最低系统要求、隐私权限和字节大小，使用 Release 的发布时间、更新说明及下载地址生成 AltStore / SideStore 格式的 `apps.json`。
3. 将 `apps.json` 和应用图标提交到独立的 `source` 分支，更新上面的固定 raw 链接；保留历史版本并将最高版本放在首位。

不需要 Apple 证书、描述文件或额外 secrets，也不需要启用 GitHub Pages。仓库必须公开，匿名客户端才能访问源和 Release。首次成功发布后才会生成 `source` 分支。

重跑发布任务会使用已经发布的原始 IPA，避免二次构建改变文件大小；发布旧标签不会把源的最新版本降级。若 Release 已成功但源更新失败，可在 Actions 重跑任务。

本地检查源生成（先构建 IPA，将 `X.Y.Z` 替换为该 IPA 的实际版本号）：

```sh
python3 -m unittest discover -s Scripts/tests -v
python3 Scripts/generate-source.py --ipa dist/AutoSignStore.ipa \
  --repository tignioj/auto-sign-store --tag vX.Y.Z --output dist/apps.json
```

源格式参考 [AltStore 文档](https://faq.altstore.io/developers/make-a-source)，分发方式参考 [Kazumi 源](https://github.com/ChouChiu/Kazumi-AltStore-Source/tree/kazumi)。源是应用元数据 JSON，IPA 则托管在 GitHub Releases；无需单独部署应用商店服务器。

## 局域网 API v1

Mac 端监听 TCP `8091`，广播 Bonjour `_autosign._tcp`。所有接口要求 `Authorization: Bearer <配对密钥>`，使用 JSON，日期为 ISO 8601。

| 方法 | 路径 | 内容 |
| --- | --- | --- |
| GET | `/v1/status` | 协议版本、Mac 名称、设备、应用、任务、可更新列表及源检查状态 |
| GET | `/v1/sources` | 获取 Mac 保存的源及应用列表 |
| POST | `/v1/sources` | 添加或更新 `{ "url": "源JSON地址" }`，返回源列表 |
| POST | `/v1/sources/refresh` | 刷新指定 `{ "url": "源JSON地址" }`，返回源列表 |
| POST | `/v1/sources/remove` | 移除指定 `{ "url": "源JSON地址" }`，返回剩余源列表 |
| POST | `/v1/install` | 提交 `{ "requestID": "UUID", "deviceUDID": "设备UDID", "sourceURL": "已订阅源的规范地址", "bundleIdentifier": "源中的应用标识" }`，返回任务 |
| POST | `/v1/refresh` | 提交 `{ "requestID": "UUID", "deviceUDID": "设备UDID", "appIDs": ["应用记录ID"] }`，返回任务 |
| POST | `/v1/updates/check` | 立即检查所有源，返回最新状态；请求体 `{}` |
| POST | `/v1/updates` | 提交与刷新相同结构的请求，按应用记录 ID 批量更新，返回任务 |
| GET | `/v1/jobs/{任务UUID}` | 查询持久化的逐应用进度与安装结果 |

状态接口可选的 `capabilities` 数组包含 `sources` 和 `install` 时支持手机源管理和安装；旧 Mac 未声明时客户端提示更新，续签仍可用。安装任务带可选 `installRequest`，复用现有任务查询及逐项状态结构。手机仅提交源和应用选择，不提交 Mac 文件路径、私钥、描述文件或下载内容。

`capabilities` 中的 `updates` 表示支持版本更新；状态可选字段 `availableUpdates` 和 `sourceCheck` 提供更新列表、检查时间及失败源。更新任务带 `updateRequest`，与安装、续签请求编号不能混用，旧客户端忽略这些可选字段。

`capabilities` 中的 `profile-refresh` 表示支持优先仅更新描述文件续签，客户端据此显示说明；实际是否回退完整安装由 Mac 判断。`Info.plist` 的 `AutoSignStoreClient = true` 标记用于识别 Store，使其在批量任务中最后处理。

`appIDs` 为状态接口返回的记录 ID，不是 Bundle ID。刷新和更新任务每批限 1–50 个应用，只能包含同一设备的应用。Mac 串行执行应用任务；忙碌返回 `409`。手机先保存 UUID 请求编号，Mac 在返回 `202` 前持久化任务；同一个请求编号与相同参数重复提交返回原任务，复用编号但改变参数或任务类型返回 `409`。密钥错误返回 `401`。

Mac 保存在 `~/Library/Application Support/AutoSign/Store/`：原 IPA、每个应用的独立描述文件、应用库和任务历史。现有手动安装与 launchd 自动安装都会更新该库；进程间文件锁防止同时调用签名和 Xcode 描述文件生成。私有文件路径、证书和描述文件不会通过 API 下发给手机。

手机配对密钥保存在钥匙串，Mac 可重置密钥。服务使用局域网 HTTP，密钥不等于传输加密。只在可信局域网使用，不要将 8091 端口映射到公网。客户端拒绝公网服务地址、带凭据的服务 URL、额外路径和重定向。

## 验证

```sh
swift test
python3 -m unittest discover -s Scripts/tests -v
xcodebuild -project AutoSignStore.xcodeproj -scheme AutoSignStore \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

客户端测试覆盖局域网地址校验、鉴权头、协议版本、错误传播、源管理及安装协议、更新协议、旧服务兼容、刷新请求及日期边界。源生成测试检查 IPA 元数据、标签匹配、隐私字段及历史版本顺序。Mac 端测试请在 [auto-sign 仓库](https://github.com/tignioj/auto-sign) 运行 `swift test`。

真机验证已覆盖无线源下载及覆盖安装、免费账号新 7 天续签、仅更新描述文件、Store 自身刷新及重开恢复。“更新 / 一键更新全部”流程已通过自动化测试和模拟器验证，尚未完成该流程的真实 Apple 签名及真机版本升级实测；实际续签与安装仍需在自己的设备、Xcode 账号和描述文件环境中验证。

参考：[AltServer 的 Wi-Fi 工作方式](https://faq.altstore.io/altstore-classic/altserver)、[Apple 本地网络权限](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)、[Apple 本地网络 ATS 配置](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking)。
