import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/item.dart';
import '../data/models/walnut.dart';
import '../pages/collection/add_item_sheet.dart';
import '../pages/collection/add_patina_page.dart';
import '../pages/collection/add_walnut_sheet.dart';
import '../pages/collection/item_detail_page.dart';
import '../pages/collection/walnut_detail_page.dart';
import '../pages/settings/nas_sync_page.dart';
import '../widgets/image_viewer.dart';

/// 统一路由（评审意见 P0 第二层）。
///
/// 收敛散落的 Navigator.push / MaterialPageRoute：详情页跳转「传参仅 id」
/// （P0 第一层已将详情页改为只收 int id），其余页面走类型安全 helper。
/// 不引入第三方路由库、不改动 MaterialApp —— 仅做跳转收敛，
/// 降低一次性动导航契约的风险。
abstract class AppRouter {
  // 语义化路由名（供将来接 onGenerateRoute / 深链；当前 helper 内部仍用 MaterialPageRoute）
  static const String walnutDetail = '/walnut/:id';
  static const String itemDetail = '/item/:id';

  /// 核桃详情：传 id
  static Future<T?> toWalnutDetail<T>(BuildContext context, int id) =>
      Navigator.of(context)
          .push<T>(MaterialPageRoute(builder: (_) => WalnutDetailPage(id)));

  /// 其他类详情：传 id
  static Future<T?> toItemDetail<T>(BuildContext context, int id) =>
      Navigator.of(context)
          .push<T>(MaterialPageRoute(builder: (_) => ItemDetailPage(id)));

  /// 全屏大图查看（已落盘原图绝对路径）
  static Future<T?> toImageViewer<T>(
          BuildContext context, List<String> abs, int initial) =>
      Navigator.of(context).push<T>(MaterialPageRoute(
          builder: (_) =>
              ImageViewer(files: abs.map((p) => XFile(p)).toList(), initial: initial)));

  /// NAS 同步设置
  static Future<T?> toNasSync<T>(BuildContext context) =>
      Navigator.of(context)
          .push<T>(MaterialPageRoute(builder: (_) => const NasSyncPage()));

  /// 新增核桃（全屏）
  static Future<void> toAddWalnut(BuildContext context) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => const AddWalnutSheet()));

  /// 新增其他类（可带初始品类）
  static Future<void> toAddItem(BuildContext context, [String? initialType]) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => AddItemSheet(initialType: initialType)));

  /// 编辑核桃（沿用预填对象契约）
  static Future<void> toEditWalnut(BuildContext context, Walnut w) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => AddWalnutSheet(editWalnut: w)));

  /// 编辑其他类
  static Future<void> toEditItem(BuildContext context, Item it) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => AddItemSheet(editItem: it)));

  /// 新增走色（绑定某核桃 id）
  static Future<bool?> toAddPatina(BuildContext context, int walnutId) =>
      Navigator.of(context).push<bool>(MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => AddPatinaPage(walnutId: walnutId)));
}
