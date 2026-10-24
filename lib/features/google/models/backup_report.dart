class BackupReport {
  int uploaded = 0;
  int skipped = 0;
  int tooLarge = 0;
  final List<String> failed = []; // Opaque IDs only, never filenames or plaintext in logs
  bool cancelled = false;

  bool get isSuccess => failed.isEmpty && !cancelled;
}

class BackupProgress {
  const BackupProgress(this.done, this.total);
  final int done;
  final int total;

  double get fraction => total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
}
