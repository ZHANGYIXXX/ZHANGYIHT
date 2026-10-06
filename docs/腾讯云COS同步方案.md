# 腾讯云 COS 云同步方案 · 替代极空间 WebDAV

> 状态：**代码已落地（`lib/cloud/`），尚未用真实密钥联调验证**。
> 起草日期：2026-10-06　　取代：`极空间数据互通设计稿.md`（已废弃归档）

---

## 0. 为什么换方案

原方案走极空间 WebDAV 直连，实测三条路全部堵死：

| 尝试 | 实测结果 | 结论 |
|---|---|---|
| 同局域网连 `192.168.0.106:60614` | `errno=111 Connection refused` | 端口未监听 / 协议不匹配 |
| 补 Android `INTERNET` 权限后 | errno 从 `1`(EPERM) → `111`(ECONNREFUSED) | **权限修复确实生效**，但对方拒绝 |
| 网段扫描 `192.168.0.0/24` | 仅 4 台在线（路由器 / .106 / .107 打印机 / .114 本机） | NAS 不在本机网段 |
| 极空间「远程访问」 | 官方文档：**仅支持网页访问**，不支持非网页服务转发 | WebDAV 跨地点不通 |

**根因**：NAS 在家中，手机与电脑在另一处，网络不通；且极空间远程访问本身不转发热路径 WebDAV 端口。

**换云对象存储的理由**：COS 走公网 HTTPS，只要能上网就能通，且手机和电脑在同一片公网可达——彻底绕开"东西不在一个地方"这个死结。

---

## 1. 为什么不用官方 COS 插件

| 方案 | 支持平台 | 结论 |
|---|---|---|
| `tencentcloud_cos_sdk_plugin` | iOS / Android / 鸿蒙 | ❌ **不支持 Windows**，本项目 PC 端必需 |
| 纯 Dart + `http` + `crypto` | 全平台 | ✅ 采用 |

COS 的 REST 接口与签名算法是公开规范，客户端逻辑仅约 200 行，换来的是**零新增依赖 + 双端通吃**。

---

## 2. 远端布局

```
<Bucket>/壹ZHANG核/
  pc/       ← Windows 端快照（deviceSubdir = pc）
  phone/    ← Android 端快照（deviceSubdir = phone）
  other/    ← 兜底
```

每设备一份**独立文件快照**，不合并——这是继承原设计的有意选择：设备间不互相覆盖，冲突问题在架构层面就不存在。
（代价是换机恢复需手工把 `pc/` 的内容拷到手机端目录，见 §5。）

---

## 3. 已实现能力

| 能力 | 类 | 方法 |
|---|---|---|
| 连通性探测 | `CosClient` | `testConnection()` — HEAD 桶根，403/404 分别给可读错误 |
| 单文件上传 | `CosClient` | `uploadFile()` — ≤8MB 单 PUT，>8MB 自动分片上传 |
| 下载 | `CosClient` | `downloadObject()` |
| 远端大小校验 | `CosClient` | `headSize()` |
| 全量备份 | `CloudSyncOrchestrator` | `backupAll()` — 索引 → 比对 size → skip/上传 → 上传后复验 |
| 完整性校验 | `CloudSyncOrchestrator` | `verifyRemoteSizes()` |
| 回拉恢复 | `CloudSyncOrchestrator` | `restoreAll()` |
| 远端路径规范化 | `FilenameNormalizer` | 非法字符、首尾点/空格、128 长度上限、`..` 拦截 |
| 内容哈希 | `integrity.dart` | SHA-256 |

配置界面：`设置 → 云同步设置`（Bucket / Region / SecretId / SecretKey / 远端目录前缀）。

---

## 4. ⚠️ 未验证项（交付时必须如实告知）

**COS 签名算法从未用真实腾讯云密钥跑过一次。** 属于纸面正确，实现依据是官方文档的 HMAC-SHA1 签名流程。
`flutter test` 因本机 vswhere 挂起问题从未跑通，无自动化用例覆盖签名。

首次真机使用时的预期排查路径：
1. 「测试连接」若返回 403 → 优先怀疑 SecretId/Region 配错，其次才是签名；
2. 若返回 400 且报签名相关错误 → 签名实现有问题，需要对照官方文档逐字段复核；
3. 上传若能成功但 `x-cos-content-sha1` 报错 → 签名头列表与实际请求头不一致。

---

## 5. 已知限制

- **换机恢复需手工干预**：新设备远端目录名不同（`phone/` vs `pc/`），`restoreAll()` 只读本机对应子目录，不会自动跨设备取数据。彻底解决需引入共享记录层（即废弃设计稿的思路），属 V3。
- **SecretKey 明文存储**在 shared_preferences。注释已标注建议迁 `flutter_secure_storage`，V3 处理。
- **无冲突合并**：多端同时改同一记录不会合并，只会各存各的快照。
- **Region 一旦配错**：对象会传到另一个地域的桶里，需手动搬。

---

## 6. 相关提交

| 提交 | 内容 |
|---|---|
| `bfc4672` | 修复 Android 构建阻塞（Gradle 仓库模式 / 中文路径 / sqlite3 镜像） |
| `fe3a637` | 移除极空间 WebDAV 全部代码，接入 COS |
| `before-remove-zspace` | 备份分支，指向 `bfc4672`（极空间代码可随时取回） |