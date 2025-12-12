class BatchOperationResult {
  final List<String> succeededPaths;
  final List<String> failedPaths;
  final List<String> errorMessages;

  const BatchOperationResult({
    required this.succeededPaths,
    required this.failedPaths,
    required this.errorMessages,
  });

  int get successCount => succeededPaths.length;

  int get failCount => failedPaths.length;

  bool get allSucceeded => failedPaths.isEmpty;

  static const empty = BatchOperationResult(
    succeededPaths: <String>[],
    failedPaths: <String>[],
    errorMessages: <String>[],
  );
}
