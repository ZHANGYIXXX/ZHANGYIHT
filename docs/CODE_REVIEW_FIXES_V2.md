# V2 全面代码审查 — 已完成事项 & 后期避坑指南

> 审查范围：`H:\Desktop\壹ZHANG核\V2\代码`（Flutter 3.x / Dart 3.x，核桃/文玩收藏管理 App）
> 入口：`main.dart` → `App`（`ProviderScope` 内）→ `AppShell`
> 工具：`flutter analyze`、`dart fix --apply`、逐文件人工读审
> 结果：**46 项静态问题（1 error + 45 info）→ 0 issues**

---

## 一、本次已完成事项清单（共 15 项）

### 安全 / 工具脚本（按用户确认跳过 PAT / 签名证书 / SSL / V1 路径，仅删除两个工具脚本）

| #   | 类别     | 文件                                       | 修改要点                                                                              |
| --- | -------- | ------------------------------------------ | ------------------------------------------------------------------------------------- |
| 0   | 工具清理 | `ci/push_files.py`、`tools/pack_upload.py` | 改用正式 git + CI 后删除（避开 V1 路径硬编码 + `token.txt` 依赖）                     |

### 二、真实逻辑错误（3 项）

| #   | 类别       | 文件                                                  | 修改要点                                                                                                                |
| --- | ---------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 5   | 展示错误   | `lib/logic/format.dart`                               | `formatDays` 月分支用 `n ~/ 30` + `n % 30`，处理"整月无余数"                                                            |
| 6   | 状态缓存   | `lib/logic/providers.dart` + 4 个 sheet/detail 调用点 | `refreshCollection` 新增 `{walnutId, itemId, owner}`，按 key 失效对应 `*ByIdProvider`；sheets/detail 保存/删除处传入 id  |
| 7   | 数据一致性 | `lib/logic/seed.dart` + `lib/data/daos/walnut_dao.dart` | 整批 `db.transaction`，DAO 新增 `maxSeqSameDayTxn/insertTxn`；`catch` 打日志不静默；标记位事务提交后置位           |

### 三、潜在崩溃 / 健壮性（9 项）

| #   | 类别       | 文件                                          | 修改要点                                                                                |
| --- | ---------- | --------------------------------------------- | --------------------------------------------------------------------------------------- |
| 8   | 空安全     | `lib/data/models/{item,walnut,patina}.dart`  | 可空列 `as num` / `as String` 全改 `as num?` / `as String?` + 默认值                    |
| 9   | 安全随机   | `lib/sync/webdav_client.dart`                 | `_randomHex` 改用 `Random.secure()`，引入 `dart:math`                                  |
| 10  | 鉴权重试   | `lib/sync/webdav_client.dart`                 | 新增 `_send` 统一封装，401 → 重新解析 Digest → 重发一次；6 个方法全部走 `_send`        |
| 11  | DAO 健壮   | `lib/data/daos/{walnut_dao,item_dao}.dart`    | `update` 校验 `id == null` 抛 `ArgumentError`                                          |
| 12  | 并发守卫   | `lib/data/database.dart`                      | `instance` 用 `_initCompleter` 守卫并发首调；`close` 重置 completer                    |
| 13  | 完整性     | `lib/sync/orchestrator.dart`                  | `backupAll` 上传后 `client.headSize` 比对大小，失败计入 `SyncResult.failed + errors`   |
| 14  | 路径安全   | `lib/data/image_store.dart`                   | `deleteFile` 用 `p.canonicalize` + `p.isWithin` 校验不越目录                            |
| 15  | 索引越界   | `lib/logic/router.dart`                       | `toImageViewer` 的 `initial.clamp(0, abs.length-1)`                                     |
| 17  | 设计解耦   | `lib/logic/providers.dart`                    | 新增 `tokensProvider` 返回 `Map<String, Color>` 颜色快照，widget 可显式 watch           |

### 四、静态分析 / 健壮性（3 项批量）

| #   | 类别     | 文件                                                                                                | 修改要点                                                                                                |
| --- | -------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 4   | 测试     | `test/widget_test.dart`                                                                              | 替换失效的 `MyApp` 脚手架测试为真实冒烟测试（`ProviderScope(child: App())`）                            |
| 4   | UI 守卫 | 6 个 UI 文件（`add_item_sheet`、`add_walnut_sheet`、`item_detail_page`、`walnut_detail_page`、`settings_page` 等） | 20 处 `use_build_context_synchronously` 用 `if (!mounted) return;` 或 `if (context.mounted) ...` 守卫 |
| —   | Lint 自动 | 全项目                                                                                              | `dart fix --apply` 自动修 23 项（`prefer_const_*`、`curly_braces`、`prefer_interpolation`、`prefer_function_declarations`、`unnecessary_const`） |
| —   | Deprecated | `app.dart`、`cover_carousel.dart`、`image_viewer.dart`                                              | `ColorScheme.background`→`surface`；`withOpacity`→`withValues(alpha:)`；`Matrix4.translate/scale`→`setEntry + diagonal3Values` |

### 验证结果
```
$ cd C:\yz && flutter analyze
Analyzing yz...
No issues found! (ran in 1.8s)
```
（真实项目 `H:\…\V2\代码` 因 Flutter 分析服务器在中文路径下崩溃，无法直接 analyze；用 `C:\yz` 目录联接验证通过。）

---

## 二、后期避坑指南（17 条，按层分类）

### A. 数据层

**1. 可空列禁止 `as num` / `as String` 强转**
SQLite 列未声明 `NOT NULL` 即为可空。`fromMap` 必须用 `as num?` + `?? 0` / `as String?` + `?? ''`。否则：导入历史数据、手工改库、备份恢复，直接 `_CastError` 闪退。

**2. 批量写入必须包 `db.transaction`**
sqflite 默认每条 `insert` 即自动提交。循环里中途失败会留半成品脏数据；标记位"先置 or 提交后置"决定了幂等性。事务 + 标记位"提交后才置位"是唯一正确的幂等写法。

**3. DAO `update` 必须校验 `id != null`**
拿 `id == null` 的对象调 `update`，SQL 变 `WHERE id = NULL`，匹配 0 行**不报错**，编辑结果"静默丢失"。入口校验抛 `ArgumentError` 是最便宜的第一道防线。

**4. 数据库单例首调并发**
`if (_db != null) return _db!; _db = await _init();` 之间存在双重初始化窗口（即便 sqflite 有 `singleInstance` 兜底，仍脆弱）。用 `Completer` 守卫才是异步并发安全的写法。

### B. 状态管理 (Riverpod)

**5. `FutureProvider.family` 不能"整体失效"**
`ref.invalidate(walnutByIdProvider)` 编译就过不了。必须按 key：`ref.invalidate(walnutByIdProvider(id))`。所以"保存后列表/详情都刷新"必须把 id 一路传到失效调用点。

**6. 避免"颜色双源头"**
全局静态 + Provider 看似方便，但 widget 必须显式 `ref.watch(主题 Provider)` 才会随主题重建。两条路任选其一，不要并存：
- 全经 Provider（推荐，可做单元/搜索）
- 全静态 + `MaterialApp.build` 里 `applyTheme(key)` 后整体重建（靠 MaterialApp 重建传播）

本次加的 `tokensProvider`（`Map<String, Color>` 快照）是介于两者之间的过渡形态——能 watch，但读的是静态字段本身。

### C. 网络 / 同步

**7. Digest 401 重试不能只写在 `propfind`**
服务端 nonce 默认 1–10 分钟过期；长备份跑几十分钟中途任何 `put/get/delete/headSize/mkcol` 拿到 401 就会整批失败。必须抽 `_send` 统一封装，所有方法共享 401→重新握手→重发一次。

**8. 鉴权随机数必须 `Random.secure()`**
Digest cnonce 之类的随机值，用 `DateTime.now().microsecondsSinceEpoch % 256` 是可预测伪随机（各字节高度相关）。永远用 `dart:math` 的 `Random.secure()`。

**9. 上传完整性不能只靠"传上去就算成功"**
至少做 HEAD / 大小比对（`client.headSize` 比对本地大小），否则远端吞字节 / 部分写入你永远不知道。完整校验用 `sha256` 对比远端 etag 是更彻底的方案。

### D. UI 与异步

**10. `await` 之后使用 `BuildContext` 必须守卫**
`Navigator.pop(context)` / `ScaffoldMessenger.of(context)` / `showDialog(context: ...)` 写在 `await` 之后必须：
- StatefulWidget：`if (!mounted) return;` 或 `if (context.mounted) ...`
- StatelessWidget / ConsumerWidget：`if (context.mounted) ...`

`use_build_context_synchronously` 看似唠叨，但真的是"页面已卸载仍去访问 Element"的崩溃源。

**11. `Matrix4` 级联赋值当心 void 返回值**
`Matrix4.setEntry` 返回 `void`，先 `setEntry` 再 `.multiply` 会触发 `use_of_void_result`。要么先存到变量再 mutate，要么用返回 `Matrix4` 的方法（`translateByVector3` / `scaleByVector3`）。

### E. 工具链 / 环境

**12. Flutter analyzer 在中文路径下崩溃**
是 Dart SDK `LspByteStreamServerChannel` 的已知问题（LSP 帧里 UTF-8 中文截断 JSON）。日常开发用**目录联接**绕开：
```powershell
New-Item -ItemType Junction -Path C:\yz -Target "H:\Desktop\壹ZHANG核\V2\代码"
```
之后 `cd C:\yz && flutter analyze` / `dart fix` 全部走 ASCII 路径。

⚠️ **删除联接的安全姿势**：必须用 `cmd /c rmdir C:\yz`。**绝对不要** `Remove-Item C:\yz -Recurse`——会穿透 junction 把 `H:\` 真实项目一起删掉。

**13. `dart fix --apply` 是 lint 处理标配**
大部分 `prefer_const_*` / `curly_braces` / `prefer_interpolation` / `prefer_function_declarations` / `unnecessary_const` 都能自动修。先 `dart fix --apply` 再人工处理 `deprecated_member_use`、`use_build_context_synchronously` 等需要改语义的项。

**14. deprecated API 迁移速查**
- `ColorScheme.background` → `surface`（Flutter 3.22+）
- `Color.withOpacity(x)` → `Color.withValues(alpha: x)`
- `Matrix4.translate/scale(...)` → `setEntry` + `Matrix4.diagonal3Values` 或 `translateByVector3` / `scaleByVector3`
- `flutter analyze` 的 `deprecated_member_use` 列表里逐项处理；`dart fix` 通常不会自动修 deprecated。

### F. 其它

**15. 删除外部文件不可信**
`deleteFile(rel)` 的 `rel` 来自 DB / 用户输入，拼接前必须 `p.canonicalize(p.join(base, rel))` 再 `p.isWithin(base, resolved)`，否则 `../etc/passwd` 之类就把目录外文件删了。

**16. 种子 / 预置数据导入的"幂等"三件套**
① `db.transaction` 全提交原子；② 标记位**在事务成功提交之后**置位；③ 用唯一键（`code`）做 `INSERT OR IGNORE` 或先查后插去重。光靠 `try/catch` 吞异常不置标记 = 下次启动重复灌入。

**17. 用户传入的索引 / 下标先 clamp**
`initial` / `index` 永远先 `clamp(0, list.length-1)`（空列表单独处理），不要相信上游一定合法。

---

## 三、回顾清单（下次代码审查可直接复用）

- [ ] `fromMap` 是否有可空列被 `as T` 强转
- [ ] 批量 DB 操作是否包 `db.transaction`
- [ ] DAO `update/delete` 是否校验 id 非 null
- [ ] 数据库/网络单例首调是否有并发守卫
- [ ] Riverpod family 失效是否按 key
- [ ] Digest/Bearer 等鉴权是否有 401→重试统一封装
- [ ] 鉴权随机值是否 `Random.secure()`
- [ ] 上传后是否有大小/哈希校验
- [ ] 所有 `await` 后用 `context` 的地方是否 `mounted` / `context.mounted` 守卫
- [ ] 删除文件/解析路径是否有 `isWithin` 校验
- [ ] 索引/下标是否 `clamp`
- [ ] 中文路径下 analyze → 用 `C:\yz` 联接
- [ ] `dart fix --apply` 是否先跑过
- [ ] deprecated_member_use 列表是否清空