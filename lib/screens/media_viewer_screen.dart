// lib/pages/media_viewer_screen.dart - COMPLETELY FIXED VERSION

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive/hive.dart';
import '../models/chat_model.dart';

class MediaViewerScreen extends StatefulWidget {
  final String mediaUrl;
  final String messageId;
  final bool isLocalFile;
  final int chatId;

  const MediaViewerScreen({
    Key? key,
    required this.mediaUrl,
    required this.messageId,
    required this.isLocalFile,
    required this.chatId,
  }) : super(key: key);

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  final PageController _pageController = PageController();
  final _messageBox = Hive.box<Message>('messages');

  List<Message> _mediaMessages = [];
  int _currentIndex = 0;
  double _verticalDragOffset = 0.0;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _loadMediaMessages();
  }

  void _loadMediaMessages() {
    try {
      // Get all media messages for this chat
      final allMessages = _messageBox.values.toList();
      _mediaMessages = allMessages
          .where((msg) =>
      msg.chatId == widget.chatId &&
          (msg.messageType == 'media' || msg.messageType == 'encrypted_media') &&
          msg.messageContent.isNotEmpty &&
          !msg.messageContent.contains('[Media URL Missing]') &&
          !msg.messageContent.contains('[Decryption Failed]'))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Find current index - EXACT MATCH
      _currentIndex = _mediaMessages.indexWhere((msg) =>
      msg.messageId == widget.messageId);

      if (_currentIndex == -1) {
        // Fallback: try to match by media URL
        _currentIndex = _mediaMessages.indexWhere((msg) =>
        msg.messageContent == widget.mediaUrl);
      }

      if (_currentIndex == -1) _currentIndex = 0;

      print("📸 Loaded ${_mediaMessages.length} media messages, current index: $_currentIndex");

      // Set page controller to current index
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && _mediaMessages.length > 1) {
          _pageController.jumpToPage(_currentIndex);
        }
      });

    } catch (e) {
      print("❌ Error loading media messages: $e");
    }
  }

  void _goToNextImage() {
    if (_currentIndex < _mediaMessages.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousImage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _verticalDragOffset += details.primaryDelta!;
    final screenHeight = MediaQuery.of(context).size.height;
    final dragPercentage = (_verticalDragOffset / screenHeight).abs();

    setState(() {
      _opacity = 1.0 - dragPercentage.clamp(0.0, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dragPercentage = (_verticalDragOffset / screenHeight).abs();

    if (dragPercentage > 0.2) { // 20% threshold to close
      Navigator.of(context).pop();
    } else {
      // Reset to original position
      setState(() {
        _verticalDragOffset = 0.0;
        _opacity = 1.0;
      });
    }
  }

  // ✅ FIXED: CORRECT HERO TAG FOR EACH IMAGE
  String _getHeroTag(Message message) {
    return '${message.messageId}_${message.messageContent}';
  }

  Widget _buildMediaItem(Message message, int index) {
    final mediaUrl = message.messageContent;
    final isLocalFile = mediaUrl.startsWith('/') ||
        mediaUrl.contains('cache') ||
        mediaUrl.contains('temp_') ||
        (File(mediaUrl).existsSync() && !mediaUrl.startsWith('http'));

    final heroTag = _getHeroTag(message);
    final isCurrentImage = index == _currentIndex;

    try {
      if (isLocalFile) {
        return GestureDetector(
          onVerticalDragUpdate: isCurrentImage ? _onVerticalDragUpdate : null,
          onVerticalDragEnd: isCurrentImage ? _onVerticalDragEnd : null,
          child: Transform.translate(
            offset: Offset(0, isCurrentImage ? _verticalDragOffset : 0),
            child: Opacity(
              opacity: isCurrentImage ? _opacity : 1.0,
              child: Hero(
                tag: heroTag, // ✅ EXACT SAME TAG AS CHATSCREEN
                child: PhotoView(
                  imageProvider: FileImage(File(mediaUrl)),
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 4.0,
                  initialScale: PhotoViewComputedScale.contained,
                ),
              ),
            ),
          ),
        );
      } else {
        return GestureDetector(
          onVerticalDragUpdate: isCurrentImage ? _onVerticalDragUpdate : null,
          onVerticalDragEnd: isCurrentImage ? _onVerticalDragEnd : null,
          child: Transform.translate(
            offset: Offset(0, isCurrentImage ? _verticalDragOffset : 0),
            child: Opacity(
              opacity: isCurrentImage ? _opacity : 1.0,
              child: Hero(
                tag: heroTag, // ✅ EXACT SAME TAG AS CHATSCREEN
                child: PhotoView(
                  imageProvider: CachedNetworkImageProvider(mediaUrl),
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 4.0,
                  initialScale: PhotoViewComputedScale.contained,
                  loadingBuilder: (context, event) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 50),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to close',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 50),
            const SizedBox(height: 16),
            Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ✅ FIXED: PAGE VIEW STARTS FROM CURRENT IMAGE
            if (_mediaMessages.length > 1)
              PageView.builder(
                controller: _pageController,
                itemCount: _mediaMessages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _verticalDragOffset = 0.0;
                    _opacity = 1.0;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildMediaItem(_mediaMessages[index], index);
                },
              )
            else if (_mediaMessages.isNotEmpty)
              _buildMediaItem(_mediaMessages[_currentIndex], _currentIndex)
            else
              _buildSingleMediaView(),

            // CLOSE BUTTON (TOP LEFT)
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

            // IMAGE COUNTER (TOP CENTER) - Only show if multiple images
            if (_mediaMessages.length > 1)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${_mediaMessages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // SWIPE GESTURE DETECTORS FOR SINGLE IMAGE
            if (_mediaMessages.length == 1)
              Positioned.fill(
                child: Row(
                  children: [
                    // LEFT SWIPE FOR PREVIOUS
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity! < -100) {
                            _goToPreviousImage();
                          } else if (details.primaryVelocity! > 100) {
                            _goToNextImage();
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // MIDDLE AREA FOR VERTICAL DRAG
                    Expanded(
                      flex: 3,
                      child: Container(color: Colors.transparent),
                    ),

                    // RIGHT SWIPE FOR NEXT
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity! < -100) {
                            _goToPreviousImage();
                          } else if (details.primaryVelocity! > 100) {
                            _goToNextImage();
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleMediaView() {
    try {
      // ✅ FIXED: CORRECT HERO TAG FOR SINGLE IMAGE
      final heroTag = '${widget.messageId}_${widget.mediaUrl}';

      if (widget.isLocalFile) {
        return GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Transform.translate(
            offset: Offset(0, _verticalDragOffset),
            child: Opacity(
              opacity: _opacity,
              child: Hero(
                tag: heroTag, // ✅ EXACT SAME TAG
                child: PhotoView(
                  imageProvider: FileImage(File(widget.mediaUrl)),
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 4.0,
                  initialScale: PhotoViewComputedScale.contained,
                ),
              ),
            ),
          ),
        );
      } else {
        return GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Transform.translate(
            offset: Offset(0, _verticalDragOffset),
            child: Opacity(
              opacity: _opacity,
              child: Hero(
                tag: heroTag, // ✅ EXACT SAME TAG
                child: PhotoView(
                  imageProvider: CachedNetworkImageProvider(widget.mediaUrl),
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 4.0,
                  initialScale: PhotoViewComputedScale.contained,
                  loadingBuilder: (context, event) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 50),
            const SizedBox(height: 16),
            Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }
}