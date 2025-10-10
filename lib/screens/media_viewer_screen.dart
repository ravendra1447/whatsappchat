// lib/pages/media_viewer_screen.dart - ALTERNATIVE VERSION

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaViewerScreen extends StatelessWidget {
  final String mediaUrl;
  final String messageId;
  final bool isLocalFile;

  const MediaViewerScreen({
    Key? key,
    required this.mediaUrl,
    required this.messageId,
    required this.isLocalFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // FULL SCREEN IMAGE VIEWER
            _buildPhotoView(),

            // CLOSE BUTTON
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoView() {
    try {
      if (isLocalFile) {
        return PhotoView(
          imageProvider: FileImage(File(mediaUrl)),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 4.0,
          initialScale: PhotoViewComputedScale.contained,
        );
      } else {
        return PhotoView(
          imageProvider: CachedNetworkImageProvider(mediaUrl),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 4.0,
          initialScale: PhotoViewComputedScale.contained,
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }
    } catch (e) {
      return Center(
        child: Text(
          'Error: $e',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
  }
}