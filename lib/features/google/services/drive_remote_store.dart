import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:googleapis/drive/v3.dart' as drive;
import '../models/remote_file.dart';
import 'google_account_service.dart';
import 'remote_store.dart';

class DriveQuotaExceededException implements Exception {
  const DriveQuotaExceededException();
  @override
  String toString() => 'Google Drive storage quota exceeded.';
}

class DriveAuthException implements Exception {
  const DriveAuthException();
  @override
  String toString() => 'Google authentication required. Please reconnect your account.';
}

class DriveRemoteStore implements RemoteStore {
  DriveRemoteStore(this.accountService);

  final GoogleAccountService accountService;

  Future<R> _withClient<R>(Future<R> Function(drive.DriveApi api) action) async {
    final headers = await accountService.headers();
    if (headers == null) {
      throw const DriveAuthException();
    }

    final client = GoogleAuthClient(headers);
    try {
      final api = drive.DriveApi(client);
      return await _retry(() => action(api));
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 401) {
        // Attempt single token refresh
        client.close();
        final freshHeaders = await accountService.headers();
        if (freshHeaders == null) throw const DriveAuthException();
        final freshClient = GoogleAuthClient(freshHeaders);
        try {
          final api = drive.DriveApi(freshClient);
          return await _retry(() => action(api));
        } finally {
          freshClient.close();
        }
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<T> _retry<T>(Future<T> Function() fn, {int maxAttempts = 5}) async {
    int attempt = 0;
    final random = Random();

    while (true) {
      attempt++;
      try {
        return await fn();
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;

        if (e is drive.DetailedApiRequestError) {
          // Never retry client errors, not found, or storage quota exceeded
          if (e.status == 400 || e.status == 404) rethrow;
          if (e.status == 403) {
            final reason = e.errors.isNotEmpty ? e.errors.first.reason : '';
            if (reason == 'storageQuotaExceeded') {
              throw const DriveQuotaExceededException();
            }
            if (reason != 'rateLimitExceeded' && reason != 'userRateLimitExceeded') {
              rethrow;
            }
          }
          // Retry on 429 or 5xx server errors
          if (e.status != 429 && (e.status == null || e.status! < 500)) {
            rethrow;
          }
        } else if (e is! SocketException && e is! TimeoutException) {
          rethrow;
        }

        // Exponential backoff with jitter: 500ms, 1000ms, 2000ms...
        final backoffMs = (pow(2, attempt - 1) * 500).toInt();
        final jitterMs = random.nextInt(250);
        await Future.delayed(Duration(milliseconds: backoffMs + jitterMs));
      }
    }
  }

  @override
  Future<Map<String, RemoteFile>> list() async {
    return _withClient((api) async {
      final result = <String, RemoteFile>{};
      String? pageToken;

      do {
        final listResponse = await api.files.list(
          spaces: 'appDataFolder',
          q: 'trashed = false',
          pageSize: 1000,
          pageToken: pageToken,
          $fields: 'nextPageToken, files(id, name, size, modifiedTime, appProperties)',
        );

        final files = listResponse.files;
        if (files != null) {
          for (final f in files) {
            if (f.id == null || f.name == null) continue;
            final remote = RemoteFile(
              id: f.id!,
              name: f.name!,
              size: int.tryParse(f.size ?? '0') ?? 0,
              modified: f.modifiedTime ?? DateTime.now(),
              properties: f.appProperties != null
                  ? Map<String, String>.fromEntries(
                      f.appProperties!.entries
                          .where((e) => e.value != null)
                          .map((e) => MapEntry(e.key, e.value!)),
                    )
                  : const {},
            );

            // Newest wins if duplicate names exist
            if (!result.containsKey(remote.name) ||
                remote.modified.isAfter(result[remote.name]!.modified)) {
              result[remote.name] = remote;
            }
          }
        }

        pageToken = listResponse.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);

      return result;
    });
  }

  @override
  Future<void> upload(
    String name,
    Stream<List<int>> bytes,
    int length, {
    String? existingId,
    Map<String, String>? properties,
  }) async {
    return _withClient((api) async {
      final media = drive.Media(bytes, length);

      if (existingId != null) {
        // Update existing file: DO NOT set parents on update!
        final updateMeta = drive.File(
          name: name,
          appProperties: properties,
        );
        await api.files.update(
          updateMeta,
          existingId,
          uploadMedia: media,
        );
      } else {
        // Create new file: must set parents to appDataFolder
        final createMeta = drive.File(
          name: name,
          parents: ['appDataFolder'],
          appProperties: properties,
        );
        await api.files.create(
          createMeta,
          uploadMedia: media,
        );
      }
    });
  }

  @override
  Future<Stream<List<int>>> download(String id) async {
    return _withClient((api) async {
      final response = await api.files.get(
        id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is drive.Media) {
        return response.stream;
      }
      throw StateError('Expected Media stream from Drive download for file ID: $id');
    });
  }

  @override
  Future<void> delete(String id) async {
    return _withClient((api) async {
      await api.files.delete(id);
    });
  }
}
