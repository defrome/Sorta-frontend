import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/foundation.dart';

import '../models/analyze_models.dart';
import 'auth_session.dart';

typedef AnalyzeProgressCallback = void Function(int processed, int total);

class ApiService {
  ApiService({http.Client? client, Uri? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? defaultBaseUrl();

  static const int batchSize = 100;
  static const String _configuredBaseUrl = String.fromEnvironment(
    'SORTA_API_BASE_URL',
  );

  final http.Client _client;
  final Uri _baseUrl;

  static Uri defaultBaseUrl() {
    if (_configuredBaseUrl.isNotEmpty) {
      return Uri.parse(_configuredBaseUrl);
    }

    if (Platform.isAndroid) {
      return Uri.parse('http://10.0.2.2:8000');
    }

    return Uri.parse('http://127.0.0.1:8000');
  }

  void close() {
    _client.close();
  }

  Future<AnalyzeResponse> analyzeLibrary(
    List<AssetEntity> assets, {
    AnalyzeProgressCallback? onProgress,
  }) async {
    if (assets.isEmpty) {
      throw const ApiException('Upload at least one image.');
    }

    final total = assets.length;
    var processed = 0;
    var merged = AnalyzeResponse.empty();

    for (var start = 0; start < assets.length; start += batchSize) {
      final end = start + batchSize > assets.length
          ? assets.length
          : start + batchSize;
      final batch = assets.sublist(start, end);
      final response = await _analyzeBatch(batch);
      merged = merged.mergeWith(response);
      processed += batch.length;
      onProgress?.call(processed, total);
    }

    if (merged.summary.scannedCount == 0 || merged.totalFiles == 0) {
      return merged.copyWith(
        totalFiles: merged.totalFiles == 0 ? processed : merged.totalFiles,
        summary: merged.summary.copyWith(
          scannedCount: merged.summary.scannedCount == 0
              ? processed
              : merged.summary.scannedCount,
        ),
      );
    }

    return merged;
  }

  Future<AnalyzeResponse> _analyzeBatch(List<AssetEntity> assets) async {
    final preparedAssets = <_PreparedMediaAsset>[];

    for (final asset in assets) {
      final thumbnailBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(384, 384),
        format: ThumbnailFormat.jpeg,
        quality: 70,
      );
      if (thumbnailBytes == null) {
        continue;
      }

      final filename = await _filenameFor(asset);
      final originalSize = await _assetFileSizeBytes(asset);
      final isScreenshot = _isScreenshot(asset, filename);
      preparedAssets.add(
        _PreparedMediaAsset(
          bytes: thumbnailBytes,
          filename: filename,
          metadata: {
            'local_asset_id': asset.id,
            'filename': filename,
            'media_type': 'image',
            'is_screenshot': isScreenshot,
            'width': asset.orientatedWidth,
            'height': asset.orientatedHeight,
            'file_size': originalSize,
            'created_at': asset.createDateTime.toUtc().toIso8601String(),
          },
        ),
      );
    }

    if (preparedAssets.isEmpty) {
      throw const ApiException('Upload at least one image.');
    }

    final response = await _postAnalyzeLibrary(preparedAssets);
    debugPrint('Analyze API status: ${response.statusCode}');
    debugPrint('Analyze API body: ${response.body}');

    if (response.statusCode == HttpStatus.tooManyRequests) {
      throw DailyFreeAnalysisLimitException.fromResponse(response);
    }
    if (response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden) {
      await AuthSessionStore.clear();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_backendError(response));
    }

    try {
      return AnalyzeResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const ApiException('Invalid analysis response.');
    }
  }

  Future<http.Response> _postAnalyzeLibrary(
    List<_PreparedMediaAsset> preparedAssets,
  ) async {
    final authHeader = await AuthSessionStore.authorizationHeader(
      validateExpiry: false,
    );
    final request =
        http.MultipartRequest(
            'POST',
            _baseUrl.replace(path: '/api/v1/media/analyze-library'),
          )
          ..files.addAll(_filesFor(preparedAssets))
          ..fields['items'] = jsonEncode(
            preparedAssets.map((asset) => asset.metadata).toList(),
          );
    if (authHeader != null) {
      request.headers[HttpHeaders.authorizationHeader] = authHeader;
    }

    final streamedResponse = await _client.send(request);
    return http.Response.fromStream(streamedResponse);
  }

  List<http.MultipartFile> _filesFor(List<_PreparedMediaAsset> preparedAssets) {
    return preparedAssets.map((asset) {
      return http.MultipartFile.fromBytes(
        'files',
        asset.bytes,
        filename: asset.filename,
        contentType: MediaType('image', 'jpeg'),
      );
    }).toList();
  }

  Future<String> _filenameFor(AssetEntity asset) async {
    final fallback = '${_safeFilename(asset.id)}.jpg';
    final title = asset.title;
    if (title != null && title.trim().isNotEmpty) {
      return title;
    }

    try {
      final asyncTitle = await asset.titleAsync;
      if (asyncTitle.trim().isNotEmpty) {
        return asyncTitle;
      }
    } catch (_) {
      return fallback;
    }

    return fallback;
  }

  Future<int?> _assetFileSizeBytes(AssetEntity asset) async {
    File? file;
    try {
      file = await asset.originFile;
      return file?.length();
    } catch (_) {
      return null;
    }
  }

  String _backendError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
      if (decoded is Map<String, dynamic> && decoded['detail'] is Map) {
        final detail = (decoded['detail'] as Map).cast<String, dynamic>();
        if (detail['message'] is String) {
          return detail['message'] as String;
        }
      }
    } catch (_) {
      return 'Media analysis failed (${response.statusCode}).';
    }

    return 'Media analysis failed (${response.statusCode}).';
  }

  static String _safeFilename(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  bool _isScreenshot(AssetEntity asset, String filename) {
    final lowerFilename = filename.toLowerCase();
    final lowerPath = asset.relativePath?.toLowerCase() ?? '';
    const iosScreenshotSubtype = 1 << 2;

    return lowerFilename.contains('screenshot') ||
        lowerPath.contains('screenshot') ||
        lowerPath.contains('screenshots') ||
        (asset.subtype & iosScreenshotSubtype) == iosScreenshotSubtype;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DailyFreeAnalysisLimitException extends ApiException {
  const DailyFreeAnalysisLimitException({
    required this.dailyFreeAnalysesLimit,
    required this.dailyFreeAnalysesUsed,
    required this.dailyFreeAnalysesRemaining,
    required this.subscriptionStatus,
    String message = 'Бесплатные проверки на сегодня закончились',
  }) : super(message);

  factory DailyFreeAnalysisLimitException.fromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      if (detail is Map) {
        final detailMap = detail.cast<String, dynamic>();
        return DailyFreeAnalysisLimitException(
          dailyFreeAnalysesLimit: _intValue(
            detailMap['daily_free_analyses_limit'],
            fallback: 3,
          ),
          dailyFreeAnalysesUsed: _intValue(
            detailMap['daily_free_analyses_used'],
            fallback: 3,
          ),
          dailyFreeAnalysesRemaining: _intValue(
            detailMap['daily_free_analyses_remaining'],
          ),
          subscriptionStatus: _stringValue(
            detailMap['subscription_status'],
            fallback: 'none',
          ),
          message: _stringValue(
            detailMap['message'],
            fallback: 'Бесплатные проверки на сегодня закончились',
          ),
        );
      }
    } catch (_) {
      return const DailyFreeAnalysisLimitException(
        dailyFreeAnalysesLimit: 3,
        dailyFreeAnalysesUsed: 3,
        dailyFreeAnalysesRemaining: 0,
        subscriptionStatus: 'none',
      );
    }

    return const DailyFreeAnalysisLimitException(
      dailyFreeAnalysesLimit: 3,
      dailyFreeAnalysesUsed: 3,
      dailyFreeAnalysesRemaining: 0,
      subscriptionStatus: 'none',
    );
  }

  final int dailyFreeAnalysesLimit;
  final int dailyFreeAnalysesUsed;
  final int dailyFreeAnalysesRemaining;
  final String subscriptionStatus;
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return fallback;
}

class _PreparedMediaAsset {
  const _PreparedMediaAsset({
    required this.bytes,
    required this.filename,
    required this.metadata,
  });

  final List<int> bytes;
  final String filename;
  final Map<String, Object?> metadata;
}
