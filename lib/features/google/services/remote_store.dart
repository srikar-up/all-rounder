import 'dart:async';
import '../models/remote_file.dart';

abstract class RemoteStore {
  /// Lists all files in the remote store: name -> RemoteFile.
  /// When duplicate names are encountered, the newest file wins.
  Future<Map<String, RemoteFile>> list();

  /// Uploads or updates a file on the remote store.
  Future<void> upload(
    String name,
    Stream<List<int>> bytes,
    int length, {
    String? existingId,
    Map<String, String>? properties,
  });

  /// Downloads the content of a remote file as a stream.
  Future<Stream<List<int>>> download(String id);

  /// Deletes a file from the remote store by ID.
  Future<void> delete(String id);
}
