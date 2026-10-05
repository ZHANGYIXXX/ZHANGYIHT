// 品类缩写映射（编号前缀）
const Map<String, String> typeAbbr = {
  '核桃': 'HZ',
  '手串': 'SZ',
  '吊坠': 'DZ',
  '手把件': 'SBJ',
  '摆件': 'BJ',
};

// 4 类其他类型（非核桃）
const List<String> itemTypes = ['手串', '吊坠', '手把件', '摆件'];

// 入手平台
const List<String> channels = ['抖音', '现场', '微信', '咸鱼', '代购', '其他'];

// 全部品类（一级分类 tab 的默认项 / 二级筛选占位）
const String allCat = '全部';

// 文玩一级分类（扁平 5 类 + 全部）：用户手填品类名称后按此归类统计
const List<String> categories = ['核桃', '手串', '吊坠', '手把件', '摆件'];
