/// 批量操作结果，包含成功、失败的路径和错误信息
class BatchOperationResult {
  final List<String> succeededPaths;
  final List<String> failedPaths;
  final List<String> errorMessages;

  const BatchOperationResult({
    required this.succeededPaths,
    required this.failedPaths,
    required this.errorMessages,
  });

  /// 成功数量
  int get successCount => succeededPaths.length;

  /// 失败数量
  int get failCount => failedPaths.length;

  /// 是否全部成功
  bool get allSucceeded => failedPaths.isEmpty;

  static const empty = BatchOperationResult(
    succeededPaths: <String>[],
    failedPaths: <String>[],
    errorMessages: <String>[],
  );
}
