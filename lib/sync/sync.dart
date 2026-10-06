// ignore_for_file: dangling_library_doc_comments
/// V2 同步核心（PC 端与华为端共用）。
///
/// 模块划分：
///  - models.dart          共用数据模型（SyncConfig / SyncFileEntry / SyncResult）
///  - filename_normalizer.dart  文件名规范化层（三端一致的关键）
///  - webdav_client.dart   WebDAV 通用客户端（PROPFIND/MKCOL/PUT/GET/DELETE/HEAD，Basic+Digest）
///  - zspace_adapter.dart  极空间 Z2PRO 适配（输入 -> SyncConfig，连通性探测）
///  - sync_index.dart      本地文件 SHA-256 索引构建
///  - resume_upload.dart   断点续传上传（HEAD + Content-Range，失败回退整传）
///  - config_store.dart    同步配置存储（shared_preferences，后续迁 secure_storage）
///  - integrity.dart       完整性校验（上传前 / 下载后字节级比对）
export 'models.dart';
export 'filename_normalizer.dart';
export 'webdav_client.dart';
export 'zspace_adapter.dart';
export 'sync_index.dart';
export 'resume_upload.dart';
export 'config_store.dart';
export 'integrity.dart';
