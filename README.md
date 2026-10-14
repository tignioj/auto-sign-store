# AutoSign Store

原生 SwiftUI iPhone / iPad 客户端，通过同一局域网中的 [AutoSign](https://github.com/tignioj/auto-sign) Mac 安装及续签应用，包括 AutoSign Store 自身。Mac 1.4.1 起续签优先只更新描述文件，不兼容时重新签名并覆盖安装。支持在手机管理应用源、浏览应用，并让 Mac 自动下载、签名及安装。

## 从源安装

在 Mac AutoSign 的“选择安装包 → 从源获取”中点击 **添加 AutoSign Store 源**，也可以手动添加固定地址：

```text
https://raw.githubusercontent.com/tignioj/auto-sign-store/source/apps.json
```

选择 AutoSign Store，点击 **下载最新 IPA**，确认设备、证书和描述文件后签名安装。源中的 IPA 是未签名真机包，由 Mac 使用你自己的开发者身份签名；最低 iOS / iPadOS 17。也可以从 [GitHub Releases](https://github.com/tignioj/auto-sign-store/releases) 下载 `AutoSignStore.ipa`。

首次安装 Store 需要 Mac。安装后可直接在手机“应用源”中刷新 Store 源并安装新版，由 Mac 完成下载和覆盖安装。

## 手机源管理与安装（Store 1.1.0 / Mac 1.3.0）

两端都需要更新到此版本。本地构建产物为 `../auto-sign/dist/AutoSign.app` 和 `dist/AutoSignStore.ipa`；正式发布前，公开源仍指向已发布版本。

1. 在 Mac 运行新版 AutoSign，确认 Xcode 已登录、选好签名证书和描述文件，开启“AutoSign Store · 手机安装与续签”服务。
2. 手机配对 Mac，在“应用源”点击 **添加源**，输入 AltStore / SideStore JSON 地址；可快捷填写 Kazumi 或 Store 源。
3. 打开源，搜索或浏览应用，查看版本、大小、系统要求和更新说明。在应用详情核对目标设备，点击 **安装到设备**。
4. 在“活动”查看检查源、下载、配置签名、安装及最终结果。成功后应用进入“我的应用”，以后可直接刷新签名。

源订阅与缓存保存在 Mac，与 Mac 的“从源获取”共用。长按源可刷新或移除，左滑也可移除。源刷新失败保留原列表；手机离线显示上次同步内容。移除源不卸载应用，也不移除已安装应用的续签资料。

Mac 在安装前必须重新获取最新源，并检查下载大小、IPA 完整性和真实 Bundle ID。首次安装使用 Mac 选定的签名团队，为不同应用生成独立、稳定的团队专属标识，避免复用 Store 的标识或申请发布者已占用的标识。升级受管理应用时沿用原标识及团队，也能识别旧版手动安装时被改写标识的原始 IPA。源中最新版本始终取 `versions` 第一项；用户点安装后源有更新时，实际安装版本以任务结果为准。

任务在返回 `202` 前先保存到 Mac；手机先保存请求编号。手机退出、网络响应丢失或升级 Store 自身导致退出后，重新连接可恢复结果。相同编号和参数返回原任务，安装与刷新编号不能混用；任务执行期间 Mac 拒绝其他手机任务。服务重启会将未完成任务标记为中断，需要用户重新发起，不会自动重复安装。

签名使用原有 Xcode 流程，免费账号须获得新的 7 天描述文件才继续安装。Apple 账号、设备配对和开发者模式仍需有效。包含现有签名器不支持的扩展或权限的 IPA 会明确报错；这些任务不会显示安装成功。

## 源更新检测与一键更新（Store 1.2.0 / Mac 1.4.0）

两端升级后，Mac 局域网服务默认每 30 分钟检查所有已订阅源，启动或休眠唤醒后若已到时间会补查；安装、下载忙碌时延后。Mac 必须保持 AutoSign 运行并联网，可在服务面板关闭自动检查。

手机“我的应用”显示更新徽标、版本变化及更新说明，可点击 **更新** 或 **一键更新全部**（每批最多 50 个）；**检查更新**立即让 Mac 检查所有远端源。手机前台每 30 秒自动同步，重开自动同步；手机完全关闭时没有系统推送。离线显示缓存，部分源失败保留上次结果并提示。

版本与构建号均参与比较，避免降级或重复升级。已关联的应用固定使用原源；旧记录从保存的 IPA 识别原标识与构建号，多个源都包含同一应用且没有关联时不自动选择。移除源后停止提示该源的更新。更新前重新获取源并验证 IPA 的真实版本、构建号及应用标识；覆盖安装沿用原应用标识与签名团队。批量任务逐项保存，部分失败不影响其他项，Store 自身最后更新，重开可恢复任务结果。签名刷新仍使用原 IPA。

## 已实现

- Mac 定时检查源新版本，手机显示更新徽标，支持单个和一键批量更新。
- Bonjour 自动发现 Mac，也支持手动输入局域网 IP / `.local` 地址。
- 配对密钥鉴权，手机密钥保存在钥匙串；Mac 可重置密钥。
- 选择对应的已配对设备，查看受管理应用、版本、真实签名到期时间及最近签名时间。
- 单个刷新、批量刷新，以及批量刷新是否包含 Store 自身的开关。
- Store 自身始终最后处理；请求先写入本机，任务先写入 Mac，应用关闭后 Mac 仍继续执行。
- Mac 1.4.1 起刷新优先只更新描述文件并验证启动，不兼容时覆盖安装；旧 Store 仍兼容，更新后的界面按 `profile-refresh` 能力显示说明。
- 应用重开、请求响应丢失后可根据请求编号恢复结果；重复请求编号不会重复执行。
- 逐应用显示成功 / 失败 / 完整错误。Mac 1.2.1 起免费账号必须获得新 7 天描述文件才继续安装并显示成功。
- Mac 服务重启后，将未完成任务标记为中断，保留已完成应用的结果。
- 手机离线显示最后一次同步的应用记录，不推算新的签名有效期。

## 构建

需要完整 Xcode；最低 iOS / iPadOS 17。无第三方依赖。

```sh
cd /Users/zhangjunli/project/auto-sign-store
open AutoSignStore.xcodeproj
```

选择 `AutoSignStore` scheme 即可在模拟器运行。通过 Xcode 安装到真机时，在 Signing & Capabilities 选择自己的开发团队，使用唯一 Bundle ID。

生成供 AutoSign 签名的 **未签名 IPA**：

```sh
./Scripts/build-ipa.sh
```

输出 `dist/AutoSignStore.ipa`。这是 arm64 真机安装包，需要 AutoSign 签名后才能安装；模拟器包不能在真机运行。

工程文件已提交到目录，不依赖 XcodeGen。新增 Swift 文件后可重新生成工程：

```sh
python3 Scripts/generate-project.py
```

## GitHub 自动构建与发布

向 `main` 推送、提交 Pull Request 或在 Actions 手动运行 **Build and publish**，都会执行 Swift 核心测试、源生成测试，构建未签名真机 IPA，并上传 Actions artifact。普通构建不改变公开源。

发布正式版本时，在 `Scripts/generate-project.py` 中更新 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`，重新生成工程，提交并推送 `main`，再推送匹配版本的标签。例如发布下一个版本：

```sh
python3 Scripts/generate-project.py
git add Scripts/generate-project.py AutoSignStore.xcodeproj
git commit -m "Release 1.0.2"
git push origin main
git tag v1.0.2
git push origin v1.0.2
```

`vX.Y.Z` 标签必须属于 `main`，并与实际 IPA 的版本完全匹配。构建成功后，Actions 使用仓库自带的 `GITHUB_TOKEN`：

1. 将 `AutoSignStore.ipa` 及 SHA-256 校验文件发布到该标签的 GitHub Release。
2. 从实际 IPA 读取 Bundle ID、版本、构建号、最低系统要求、隐私权限和字节大小，使用 Release 的发布时间、更新说明及下载地址生成 AltStore / SideStore 格式的 `apps.json`。
3. 将 `apps.json` 和应用图标提交到独立的 `source` 分支，更新上面的固定 raw 链接；保留历史版本并将最高版本放在首位。

不需要 Apple 证书、描述文件或额外 secrets，也不需要启用 GitHub Pages。仓库必须公开，匿名客户端才能访问源和 Release。首次成功发布后才会生成 `source` 分支。

重跑发布任务会使用已经发布的原始 IPA，避免二次构建改变文件大小；发布旧标签不会把源的最新版本降级。若 Release 已成功但源更新失败，可在 Actions 重跑任务。

本地检查源生成：

```sh
python3 -m unittest discover -s Scripts/tests -v
python3 Scripts/generate-source.py --ipa dist/AutoSignStore.ipa \
  --repository tignioj/auto-sign-store --tag v1.0.1 --output dist/apps.json
```

源格式参考 [AltStore 文档](https://faq.altstore.io/developers/make-a-source)，分发方式参考 [Kazumi 源](https://github.com/ChouChiu/Kazumi-AltStore-Source/tree/kazumi)。源是应用元数据 JSON，IPA 则托管在 GitHub Releases；无需单独部署应用商店服务器。

## 首次安装与连接

1. 在相邻 `auto-sign` 项目运行 `./Scripts/build-app.sh`，退出旧版后打开新生成的 `dist/AutoSign.app`。
2. iPhone / iPad 先通过 USB 信任并配对 Mac，开启开发者模式。在 Finder 选中设备并启用“连接到 Wi-Fi 时显示此设备”。
3. 在 AutoSign 添加上面的 Store 源并下载 IPA，或选择本地构建的 `AutoSignStore.ipa`，选择设备、签名证书及匹配的 Development / Ad Hoc 描述文件后安装。首次安装后根据系统要求信任开发者证书。
4. Mac AutoSign 的“AutoSign Store · 手机安装与续签”中开启局域网服务。
5. 手机进入“连接”，允许本地网络权限，选择发现的 Mac，粘贴 Mac 显示的配对密钥并连接。若发现失败，手动输入 `http://Mac的局域网IP:8091`。
6. 在“我的应用”明确选择这台手机 / 平板。iOS 不提供通用的本机 UDID 读取接口，所以需要核对设备名称。
7. 点击“刷新全部应用”，或点开应用详情进行单独刷新。应用列表来自此版本 AutoSign 的成功安装记录；旧版安装的应用需用新版覆盖安装一次。

每个应用需要匹配自己的 Bundle ID 的描述文件。使用同一个明确 Bundle ID 的描述文件签多个不同应用，会被 AutoSign 重写为相同标识并互相覆盖。刷新时保持原应用标识及签名团队一致，才能覆盖安装并保留应用数据。

## 自身刷新

`Info.plist` 中的 `AutoSignStoreClient = true` 标记让 Mac 在签名后识别 Store，即使第一次安装时 Bundle ID 被描述文件重写，也能将它排在队尾。

手机先保存 UUID 请求编号，Mac 将任务写入磁盘后返回 `202`，再依次通过 Xcode 获取新的描述文件。Mac 1.4.1 起优先单独安装描述文件，读回设备文件并核对有效期延长、安装位置与版本不变，再验证应用启动；不会主动结束运行中的 Store。不兼容时才调用 `devicectl device install app` 覆盖安装并验证启动，此时 iOS 可能关闭 Store；无需让客户端保持运行。重新打开后，手机使用保存的请求编号查询 Mac 的历史任务。

这是**手机发起、Mac 获取并更新签名**的方案。Mac 需要保持开机并运行 AutoSign；手机和 Mac 需在可互访的同一网络中，Xcode 账号需要有效。启动验证需要设备解锁；网络、锁定或验证失败不会更新成功记录，也不会盲目回退重装。系统不支持读回描述文件时，完整安装路径依据验证过的新签名包、安装响应及启动检查确认结果。Store 已掉签无法打开时，可先从 Mac 发起后台续签；无法直接恢复时再覆盖安装。

当前版本提供手机手动刷新及 Mac 上已有的后台续签；没有依赖 iOS 定时后台唤醒来保证续签。Mac 1.2.1 起每次刷新会隔离匹配应用的 Xcode 缓存，向 Apple 请求新描述文件。免费账号成功后有效期为新签发时间起 7 天，不是给原到期日期累加 7 天；签发失败或返回旧文件时会报错并保留原安装。构建、网络传输和安装会占用少量时间。

Mac 会先将匹配的缓存复制到私有事务目录并写入恢复记录，随后暂时移除它们。失败时恢复，进程中断后下一次续签恢复；成功时清理过期的明确应用缓存、恢复其他应用可能共用的通配符缓存。开发者证书和私钥保持有效。此流程参考 [AltStore 获取新描述文件的实现](https://github.com/altstoreio/AltStore/blob/main/AltStore/Operations/FetchProvisioningProfilesOperation.swift) 和 [Apple 的自动签名缓存说明](https://developer.apple.com/help/account/provisioning-profiles/edit-download-or-delete-profiles/)。

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

`appIDs` 为状态接口返回的记录 ID，不是 Bundle ID。每个任务限 1–50 个应用，只能包含同一设备的应用。Mac 串行执行刷新；忙碌返回 `409`。同一个请求编号与相同参数重复提交返回原任务；复用编号但改变参数返回 `409`。密钥错误返回 `401`。

Mac 保存在 `~/Library/Application Support/AutoSign/Store/`：原 IPA、每个应用的独立描述文件、应用库和任务历史。现有手动安装与 launchd 自动安装都会更新该库；进程间文件锁防止同时调用签名和 Xcode 描述文件生成。私有文件路径、证书和描述文件不会通过 API 下发给手机。

服务使用局域网 HTTP，密钥不等于传输加密。只在可信局域网使用，不要将 8091 端口映射到公网。客户端拒绝公网地址、带凭据的 URL、额外路径和重定向。

## 验证

```sh
swift test
xcodebuild -project AutoSignStore.xcodeproj -scheme AutoSignStore \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
cd ../auto-sign
swift test
```

客户端测试覆盖局域网地址校验、鉴权头、协议版本、错误传播、源管理及安装协议、旧服务兼容、刷新请求及日期边界。Mac 测试覆盖 HTTP 分片 / 非法请求、真实 TCP 通信、自身最后刷新、请求幂等、跨设备拒绝和重启恢复，也覆盖源增删刷新、安装任务先持久化、重新获取最新版本、幂等重试及失败结果。更新测试覆盖定时间隔与重启、开关、缓存失败、版本与构建号比较、原标识与源关联、批量顺序、部分失败、成功清除提示和任务幂等。真实 Apple 续期与真机覆盖安装需要在自己的设备、Xcode 账号和描述文件环境中验证。

参考：[AltServer 的 Wi-Fi 工作方式](https://faq.altstore.io/altstore-classic/altserver)、[Apple 本地网络权限](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)、[Apple 本地网络 ATS 配置](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking)。

## 首次真机实测：2026-10-14（Mac 1.2.0，修复前）

已在 `iPhone18pm`（iPhone 18 Pro Max，iOS 27.0）安装 Store 1.0.0 build 2，Bundle ID 为 `com.tignioj.autosign.store`。通过手机完成 Bonjour 发现、局域网权限、密钥配对及设备选择。

拔掉 USB 后，CoreDevice 在测试前后均确认使用 `localNetwork`。在手机点击“刷新全部应用”，Mac 先完成 Kazumi，再完成 Store 自身的重签和覆盖安装。两个应用的安装位置均改变，确认发生实际安装。Store 在自身安装时退出，重新打开后保留配对与设备选择，自动恢复并显示两项已完成结果；手机持久化请求编号与 Mac 完成任务匹配。Kazumi 续签后也实际打开成功。

| 应用 | 无线重签及覆盖安装 | 刷新后到期时间（北京时间） | 有效期变化 |
| --- | --- | --- | --- |
| Kazumi 2.3.8 | 成功 | 2026-10-20 22:32:06 | 未延长 |
| AutoSign Store 1.0.0 build 2 | 成功，自身最后安装 | 2026-10-21 19:13:01 | 未延长 |

此次旧版本验证了手机发起、无线安装、自身刷新及重开恢复，但 Xcode 复用本地缓存，没有延长到期时间。该原因已在 Mac 1.2.1 修复。首次实测还修复了图标导出为黑色的问题，已从真机生成图标验证修复。当时两端回归测试共 41 项通过。

本地机器可读记录：[`dist/DeviceTests/verification.json`](dist/DeviceTests/verification.json)。记录不包含配对密钥或签名私钥。

## 7 天续签修复后实测：2026-10-14

Mac 已更新并运行 AutoSign 1.2.1 build 4，手机已安装 AutoSign Store 1.0.1 build 3。修复了 Xcode 复用旧描述文件缓存导致“覆盖安装成功，但有效期没有延长”的问题。新描述文件必须通过团队、应用标识、设备、UUID、签发时间及 7 天有效期校验，才继续签名安装；失败会恢复缓存并保留原安装。

先完成一轮 Mac API 刷新和一轮手机按钮刷新，两款应用每轮都取得不同 UUID 的新描述文件。随后拔掉 USB，在手机再次点击“刷新全部应用”，测试前后 CoreDevice 均确认使用 `localNetwork`。Kazumi 先刷新，Store 自身最后刷新：

| 应用 | 新签发时间（北京时间） | 新到期时间（北京时间） | 签名有效期 |
| --- | --- | --- | --- |
| Kazumi 2.3.8 | 2026-10-14 19:59:44 | 2026-10-21 19:59:44 | 168 小时 |
| AutoSign Store 1.0.1 build 3 | 2026-10-14 20:00:05 | 2026-10-21 20:00:05 | 168 小时 |

已从手机读取描述文件列表，确认两份新 UUID 和到期时间确实在设备上；两款应用的安装位置均改变。Store 覆盖安装时退出，重开后保留配对和设备选择，自动恢复并显示两项成功结果；手机持久化请求编号与 Mac 完成任务匹配。Kazumi 续签后也实际打开成功。连续刷新会从本次签发时刻重新计算 7 天，不给旧到期时间额外累加 7 天。

两端自动化测试共 48 项通过（Mac 39、iOS 核心 9）。本次机器可读记录：[`dist/DeviceTests/verification-7day.json`](dist/DeviceTests/verification-7day.json)，不包含配对密钥、私钥或账号凭据。

Mac 1.4.1 的仅描述文件刷新已另行实测：在 iPhone18pm 的 Store 1.1.0 点击批量刷新，Kazumi 与 Store 均成功续签至新签发时间起 168 小时，设备读回文件一致，安装位置、版本和进程编号保持不变；Store 自身无需退出。随后两款应用另行全新启动成功，Store 保留配对并恢复成功任务。记录及北京时间见 [Mac 端实测说明](../auto-sign/README.md#仅更新描述文件实测2026-10-14) 和 [`verification-profile-only-batch.json`](../auto-sign/dist/DeviceTests/verification-profile-only-batch.json)。

2026-10-14 更新功能验证：Mac 57 项测试、Store 核心 17 项测试全部通过；Mac Release、iOS 真机 IPA 和模拟器均构建成功。独立 iOS 26.5 模拟器使用本机测试 API 验证更新徽标、版本变化、立即检查、一键提交两应用、Store 自身排后、进度自动恢复及成功后清除更新提示。本次未进行真实 Apple 签名及真机升级实测。

## 手机源安装真机实测：2026-10-14

已在 Mac 启动 AutoSign 1.3.0 build 5，并将 iPhone18pm（iPhone 18 Pro Max，iOS 27.0）上的 Store 从 1.0.1 build 3 覆盖更新至 1.1.0 build 4。CoreDevice 确认实际版本和新的安装位置，原配对及设备选择保留。

通过真机 Store 的“添加源”新增 Kazumi 的 `refs/heads/kazumi` 公开源地址，浏览应用详情并点击“安装到 iPhone18pm”。手机提交任务后，Mac 重新获取源，从真实 GitHub Release 下载 30,463,104 字节 IPA，向 Apple 请求新描述文件，保留原 `com.tignioj.autosign.kazumi` 标识和签名团队，完成 Kazumi 2.3.8 build 20308 的签名及覆盖安装。

任务于北京时间 21:01:33 创建，21:02:20 完成。新描述文件于 21:01:54 签发，到期时间为 **2026-10-21 21:01:54**，签名有效期 168 小时；UUID 与测试前不同。设备上的应用安装位置发生变化，Kazumi 随后通过手机镜像正常启动。测试前后 CoreDevice 的连接类型均为 `localNetwork`。

执行中将 Store 切到后台，Mac 仍继续完成任务。重开 Store 后，“活动”显示安装成功，“我的应用”显示 Store 1.1.0 和 Kazumi 2.3.8；从真机读取的请求编号及缓存任务状态与 Mac 完成任务一致。测试新增的重复订阅随后从手机移除，原有 Kazumi 和 Store 源保持不变。

本次是已安装 Kazumi 的真实源下载及覆盖安装验证，未额外安装其他新应用；首次安装时生成独立应用标识的分支由自动化测试覆盖。机器可读记录及截图保存在本地：[`verification-source-install.json`](dist/DeviceTests/verification-source-install.json)、[安装完成截图](dist/DeviceTests/source-install/04-install-completed.png)。记录不包含配对密钥、私钥或账号凭据。
