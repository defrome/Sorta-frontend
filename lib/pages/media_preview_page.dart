import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/analyze_models.dart';
import '../shared/sorta_colors.dart';
import '../shared/sorta_spacing.dart';

class MediaPreviewPage extends StatefulWidget {
  const MediaPreviewPage({super.key, required this.item});

  final MediaItem item;

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  late final Future<_PreviewData> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<_PreviewData> _loadPreview() async {
    final asset = await AssetEntity.fromId(widget.item.localAssetId);
    if (asset == null) {
      throw StateError('Photo is no longer available.');
    }

    final file = await asset.originFile;
    if (file != null) {
      return _PreviewData(file: file);
    }

    final thumbnailBytes = await asset.thumbnailDataWithSize(
      const ThumbnailSize(1024, 1024),
      format: ThumbnailFormat.jpeg,
      quality: 95,
    );
    if (thumbnailBytes != null) {
      return _PreviewData(bytes: thumbnailBytes);
    }

    throw StateError('Could not load photo.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<_PreviewData>(
                future: _previewFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || snapshot.data == null) {
                    return const Center(
                      child: Text(
                        'Could not open photo',
                        style: TextStyle(color: SortaColors.secondary),
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  final image = data.file != null
                      ? Image.file(data.file!, fit: BoxFit.contain)
                      : Image.memory(data.bytes!, fit: BoxFit.contain);

                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(child: image),
                  );
                },
              ),
            ),
            Positioned(
              left: SortaSpacing.md,
              top: SortaSpacing.md,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              left: SortaSpacing.lg,
              right: SortaSpacing.lg,
              bottom: SortaSpacing.lg,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(SortaSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SortaColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: SortaSpacing.xs),
                      Text(
                        '${widget.item.category.label} · '
                        '${formatBytes(widget.item.fileSize)} · '
                        '${widget.item.width}x${widget.item.height}',
                        style: const TextStyle(
                          color: SortaColors.secondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewData {
  const _PreviewData({this.file, this.bytes});

  final File? file;
  final Uint8List? bytes;
}
