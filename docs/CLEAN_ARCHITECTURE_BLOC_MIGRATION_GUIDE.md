# AEDove Clean Architecture + BLoC 重构实施手册

> 目标：把当前项目从「UI + static service + setState」迁移到「Clean Architecture + OOP + BLoC」。
> 原则：不一次性重写，分阶段替换，始终保持可运行。

## 实施状态（2026-04-07）

- [x] Phase 0：准备期
- [x] Phase 1：Discovery 垂直切片
- [x] Phase 2：Transfer 垂直切片
- [x] Phase 3：Ads + Home Shell
- [x] Phase 4：AppInit + Settings
- [x] Phase 5：清理与测试（第一轮+第二轮）

当前验证结果：
- 页面层与 presentation 层不再直接 import service。
- AppInit/Settings/Ads/Transfer 的关键 bloc 均有基础测试。
- 关键测试通过：`flutter test test/app_init_bloc_test.dart test/settings_bloc_test.dart test/ads_bloc_test.dart test/transfer_bloc_test.dart`

## 1. 当前架构体检（你现在的真实状态）

### 1.1 现有分层现状

当前基本是两层：
- 表现层（页面）：直接持有状态、直接调 service
- service 层：static 全局方法，混合网络/协议/通知/存储/业务规则

核心问题文件：
- lib/pages/home_page.dart
- lib/pages/tabs/receive_tab.dart
- lib/pages/tabs/send_tab.dart
- lib/services/file_transfer_service.dart
- lib/services/device_discovery_service.dart

### 1.2 主要痛点

1. UI 里有业务流程
- 例如 home 页面里直接做广告拉取、轮播计时、权限、设备发现刷新。

2. static service 难测试、难替换
- 例如 file transfer、device discovery 都是 static，全局状态强耦合。

3. 状态源分散
- receive 页同时监听多个 stream，再 setState 合并，容易出现时序问题。

4. 单文件职责过重
- file_transfer_service.dart 约 850+ 行
- device_discovery_service.dart 约 1080+ 行

5. 初始化流程不可控
- main/app init 里直接调用 service 初始化，异常和依赖顺序不够清晰。

## 2. 目标架构（Clean + OOP + BLoC）

## 2.1 分层定义

### Domain（纯业务）
- entities：业务对象，不依赖 Flutter
- repositories（abstract interface）：业务依赖抽象
- usecases：单一业务动作（一个用例做一件事）

### Data（实现细节）
- datasources：对接现有 service / plugin / http / socket
- repository_impl：实现 domain repository 接口
- models + mappers：序列化和转换

### Presentation（UI + 状态）
- bloc/cubit：状态机、事件流转
- pages/widgets：只渲染 + 触发事件，不写业务流程

## 2.2 目录建议（适配当前项目）

lib/
- core/
  - errors/
  - utils/
  - constants/
- domain/
  - entities/
  - repositories/
  - usecases/
- data/
  - datasources/
  - models/
  - repositories/
- presentation/
  - bloc/
    - app_init/
    - discovery/
    - transfer/
    - ads/
    - settings/
  - pages/
  - widgets/
- di/
  - service_locator.dart

## 3. 文件级重构映射（改什么）

## 3.1 旧文件 -> 新职责

1. lib/services/file_transfer_service.dart
- 拆成：
  - data/datasources/transfer/file_transfer_remote_datasource.dart
  - data/datasources/transfer/file_transfer_local_datasource.dart
  - data/repositories/file_transfer_repository_impl.dart
  - domain/usecases/transfer/send_files_usecase.dart
  - domain/usecases/transfer/accept_transfer_usecase.dart
  - domain/usecases/transfer/deny_transfer_usecase.dart
  - domain/usecases/transfer/watch_transfer_progress_usecase.dart

2. lib/services/device_discovery_service.dart
- 拆成：
  - data/datasources/discovery/discovery_datasource.dart
  - data/repositories/device_repository_impl.dart
  - domain/usecases/discovery/start_discovery_usecase.dart
  - domain/usecases/discovery/stop_discovery_usecase.dart
  - domain/usecases/discovery/watch_devices_usecase.dart

3. lib/pages/tabs/receive_tab.dart
- 拆成：
  - presentation/bloc/transfer/transfer_bloc.dart
  - presentation/bloc/transfer/transfer_event.dart
  - presentation/bloc/transfer/transfer_state.dart
  - presentation/widgets/receive/incoming_request_list.dart
  - presentation/widgets/receive/transfer_progress_list.dart

4. lib/pages/tabs/send_tab.dart
- 拆成：
  - presentation/bloc/discovery/discovery_bloc.dart
  - presentation/widgets/send/device_list.dart
  - presentation/widgets/send/selected_files_panel.dart

5. lib/pages/home_page.dart
- 拆成：
  - presentation/bloc/ads/ads_bloc.dart
  - domain/usecases/ads/fetch_ad_config_usecase.dart
  - domain/usecases/ads/rotate_ad_usecase.dart
- 页面保留 Tab 容器和布局，移除广告轮播业务逻辑。

## 4. 先从哪里开始（起步顺序）

推荐顺序（低风险）：

1. 第一步：搭骨架 + 依赖注入（不改功能）
- 先建立目录、接口、DI，不触碰旧流程。

2. 第二步：先做 Discovery BLoC（最容易看到成果）
- 把 send 页设备列表从 setState 改成 BlocBuilder。

3. 第三步：做 Transfer BLoC（核心）
- 把 receive/send 页的传输请求与进度统一收敛到 TransferState。

4. 第四步：做 Ads BLoC
- 把 home 页广告 timer/http/切换逻辑迁出。

5. 第五步：AppInitBloc + 清理旧 static 调用
- 把初始化统一为事件驱动。

## 5. 迁移阶段计划（详细）

## Phase 0：准备期（0.5 天）

目标：引入基础依赖和规则，不改业务行为。

要做：
1. pubspec 增加依赖
- flutter_bloc
- equatable
- get_it
- dartz（可选）

2. 新增目录结构
- domain/data/presentation/core/di

3. 新增 DI 入口
- lib/di/service_locator.dart

验收：
- 编译通过
- 现有功能全部可用

## Phase 1：Discovery 垂直切片（1-2 天）

目标：完成第一个完整 feature 的 clean + bloc 迁移。

要做：
1. 抽象 repository
- domain/repositories/device_repository.dart

2. data 实现
- data/repositories/device_repository_impl.dart
- 内部先复用旧的 DeviceDiscoveryService，保证行为不变

3. use case
- start_discovery_usecase.dart
- stop_discovery_usecase.dart
- watch_devices_usecase.dart

4. bloc
- DiscoveryStarted / DiscoveryStopped / DevicesUpdated

5. 页面接入
- send_tab 改为 BlocBuilder，移除 _setupStreams 的 setState

验收：
- 设备可发现
- 设备上下线可更新
- 页面无直接监听 DeviceDiscoveryService stream

## Phase 2：Transfer 垂直切片（2-4 天）

目标：统一发送/接收/进度状态，去除页面多 stream 拼接。

要做：
1. repository 抽象
- domain/repositories/transfer_repository.dart

2. data 实现
- file transfer 先通过 adapter 包装旧 FileTransferService

3. usecases
- send_files_usecase
- accept_transfer_usecase
- deny_transfer_usecase
- watch_requests_usecase
- watch_progress_usecase

4. TransferBloc
- 事件：Load, SendFiles, Accept, Deny, RequestsChanged, ProgressChanged
- 状态：pendingRequests, activeTransfers, sendStatus, error

5. 页面接入
- receive_tab：删除 4 组 stream.listen
- send_tab：发送动作通过 bloc dispatch

验收：
- 收发文件功能稳定
- 进度显示正常
- 页面 setState 大幅减少（仅局部 UI 状态）

## Phase 3：Ads + Home Shell（1-2 天）

目标：home 页面只保留壳层，不再承载广告业务逻辑。

要做：
1. AdRepository + UseCase
- fetch_ad_schedule
- rotate_ad_item

2. AdsBloc
- AdsStarted
- AdsTicked
- AdsPaused / AdsResumed

3. home_page 接入
- 去掉 timer 管理、http 拉取、广告切换业务逻辑

验收：
- 广告显示与切换正常
- 页面代码体积明显下降

## Phase 4：AppInit + Settings（1 天）

目标：初始化与设置统一管理。

要做：
1. AppInitBloc
- 处理 Notification/Background/Permission 初始化顺序

2. SettingsBloc
- 管理 deviceName、notificationsEnabled 等设置

验收：
- 启动流程可观测
- 设置变更不再散落在页面层

## Phase 5：清理与测试（1-2 天）

目标：删除遗留路径，确保稳定。

要做：
1. 删掉页面层直连 static service 的调用
2. 保留 service 作为 datasource 内部细节
3. 加最小单测和 bloc 测试

验收：
- 页面层不直接 import service
- 关键 bloc 有测试
- 功能回归通过

## 6. 代码风格与 OOP 约束（落地规范）

1. 一个 UseCase 只做一件事
- 避免“万能 service 方法”。

2. 页面禁止业务分支
- 页面允许：dispatch event + render state。

3. repository interface 只放业务语义
- 不暴露 http/socket/plugin 细节。

4. 状态对象不可变
- 使用 copyWith + Equatable。

5. BLoC 中避免直接依赖 plugin
- plugin 调用统一放到 data datasource。

## 7. 第一周可执行清单（直接照做）

Day 1
1. 建目录
2. 加依赖
3. 建 service_locator
4. 创建 domain repository interface 空实现

Day 2
1. 完成 DeviceRepositoryImpl（内部调用旧 discovery service）
2. 完成 DiscoveryUseCases
3. 完成 DiscoveryBloc（含状态）

Day 3
1. send_tab 接入 DiscoveryBloc
2. 删除 send_tab 内设备 stream.listen
3. 回归测试设备发现

Day 4
1. 建 TransferRepository 接口与 impl（先 adapter）
2. 建 TransferBloc 雏形（先接 requests）

Day 5
1. receive_tab 接入 TransferBloc（先替换 pending requests）
2. 再替换 progress
3. 全链路联调

## 8. 风险点与规避

1. 风险：一次改太多导致回归
- 规避：按 feature 垂直切片迁移，每次只动一个页面主流程。

2. 风险：static service 与 bloc 双写冲突
- 规避：阶段内保留 adapter 单入口，页面只走 bloc。

3. 风险：多 stream 合并时序错误
- 规避：在 bloc 内用单一 state 汇总，必要时对事件去抖/串行处理。

4. 风险：平台差异导致行为漂移
- 规避：datasource 按平台分实现，domain 层不感知平台。

## 9. 你现在就该做的“第一刀”

优先做 Discovery 垂直切片，不先碰 Transfer：

原因：
1. 影响面小，成功率高。
2. 能快速把 send_tab 从 setState 迁到 bloc。
3. 为 Transfer 迁移打基础（设备来源统一）。

第一刀输出目标：
1. send_tab 不再直接监听 DeviceDiscoveryService。
2. 页面通过 DiscoveryBloc 获取设备列表。
3. 功能表现与现状一致。

## 10. 完成后的目标结果（衡量标准）

达到以下条件即可判定重构成功：

1. presentation 不直接 import services
2. 所有业务流程通过 usecase + repository
3. 主要页面没有大块 setState 业务逻辑
4. 设备发现、文件传输、广告轮播都由 bloc 管理
5. 关键流程有基础测试

---

如果你下一步确认开始实施，我建议按这份手册执行，并从 Discovery 切片直接开工。