// lib/widgets/chat_image.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ChatImage extends StatefulWidget {
  final String thumbnailUrl;
  final String fullImageUrl;
  final double? fileSizeKB;

  const ChatImage({
    super.key,
    required this.thumbnailUrl,
    required this.fullImageUrl,
    this.fileSizeKB,
  });

  @override
  State<ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<ChatImage> {
  bool _loadedFull = false;
  bool _isLoading = false;
  bool _thumbnailError = false;
  bool _fullImageError = false;

  void _loadFullImage() async {
    if (_loadedFull || _isLoading) return;

    setState(() => _isLoading = true);

    // Simulate loading delay for better UX
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _loadedFull = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loadFullImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Blurred thumbnail background (always visible as fallback)
            _buildBlurredThumbnail(),

            // Full image (appears on top when loaded)
            if (_loadedFull && !_fullImageError)
              _buildFullImage(),

            // Loading indicator
            if (_isLoading)
              _buildLoadingIndicator(),

            // File size overlay (only when not loaded)
            if (!_loadedFull && !_isLoading)
              _buildFileSizeOverlay(),

            // Error overlay for full image failure
            if (_fullImageError)
              _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurredThumbnail() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.65,
      height: 300,
      color: Colors.grey[300],
      child: Stack(
        children: [
          // Network image with blur effect
          Image.network(
            widget.thumbnailUrl,
            width: MediaQuery.of(context).size.width * 0.65,
            height: 300,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            errorBuilder: (context, error, stackTrace) {
              return _buildThumbnailPlaceholder();
            },
          ),

          // Blur overlay using BackdropFilter
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo,
              color: Colors.white54,
              size: 40,
            ),
            SizedBox(height: 8),
            Text(
              'Preview',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullImage() {
    return AnimatedOpacity(
      opacity: _loadedFull ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Image.network(
        widget.fullImageUrl,
        width: MediaQuery.of(context).size.width * 0.65,
        height: 300,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          return Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_getLoadingPercentage(loadingProgress)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _fullImageError = true;
              });
            }
          });
          return const SizedBox(); // Empty container, thumbnail remains visible
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSizeOverlay() {
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.file_download,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getFileSizeText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap to load',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 8),
            const Text(
              'Load failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                setState(() {
                  _fullImageError = false;
                  _isLoading = false;
                  _loadedFull = false;
                });
              },
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileSizeText() {
    if (widget.fileSizeKB != null) {
      if (widget.fileSizeKB! >= 1024) {
        return '${(widget.fileSizeKB! / 1024).toStringAsFixed(1)} MB';
      } else {
        return '${widget.fileSizeKB!.toStringAsFixed(0)} KB';
      }
    }
    return 'Media';
  }

  int _getLoadingPercentage(ImageChunkEvent loadingProgress) {
    if (loadingProgress.expectedTotalBytes != null) {
      return ((loadingProgress.cumulativeBytesLoaded /
          loadingProgress.expectedTotalBytes!) *
          100).round();
    }
    return 0;
  }
}