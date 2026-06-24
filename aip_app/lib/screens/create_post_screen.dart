import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final textCtrl = TextEditingController();
  bool loading = false;
  final List<File> _imageFiles = [];
  final List<File> _videoFiles = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isNotEmpty) {
      setState(() {
        for (final f in files) {
          if (_imageFiles.length + _videoFiles.length < 9) {
            _imageFiles.add(File(f.path));
          }
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (file != null && _imageFiles.length + _videoFiles.length < 9) {
      setState(() => _videoFiles.add(File(file.path)));
    }
  }

  void _removeMedia(int index) {
    setState(() {
      if (index < _imageFiles.length) {
        _imageFiles.removeAt(index);
      } else {
        _videoFiles.removeAt(index - _imageFiles.length);
      }
    });
  }

  bool get _canSubmit => (textCtrl.text.isNotEmpty || _imageFiles.isNotEmpty || _videoFiles.isNotEmpty) && !loading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => loading = true);

    final imageUrls = <String>[];
    final videoUrls = <String>[];
    final thumbnailUrls = <String>[];

    for (final file in _imageFiles) {
      final url = await ApiService.uploadFile(file);
      if (url != null) imageUrls.add(url);
    }
    for (final file in _videoFiles) {
      final result = await ApiService.uploadFileWithThumbnail(file);
      if (result != null) {
        if (result['url'] != null) videoUrls.add(result['url']!);
        if (result['thumbnail'] != null) thumbnailUrls.add(result['thumbnail']!);
      }
    }

    await ApiService.createPost(textCtrl.text, images: imageUrls, videos: videoUrls, thumbnails: thumbnailUrls);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final totalMedia = _imageFiles.length + _videoFiles.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              child: loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('发布'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  decoration: const InputDecoration(hintText: '有什么新鲜事？', border: InputBorder.none),
                  maxLines: 8,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (totalMedia > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: totalMedia,
                itemBuilder: (context, index) {
                  final isVideo = index >= _imageFiles.length;
                  final file = isVideo ? _videoFiles[index - _imageFiles.length] : _imageFiles[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isVideo
                              ? Container(
                                  width: 120, height: 120,
                                  color: Colors.black87,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const Icon(Icons.videocam, color: Colors.white54, size: 40),
                                      Container(
                                        width: 40, height: 40,
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                                      ),
                                      Positioned(bottom: 4, right: 4, child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('视频', style: TextStyle(color: Colors.white, fontSize: 10)),
                                      )),
                                    ],
                                  ),
                                )
                              : Image.file(file, width: 120, height: 120, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => _removeMedia(index),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          if (totalMedia < 9) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Color(0xFF1DA1F2)),
                  onPressed: _pickImages,
                  tooltip: '选择图片',
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, color: Color(0xFF1DA1F2)),
                  onPressed: _pickVideo,
                  tooltip: '选择视频',
                ),
                const SizedBox(width: 8),
                Text('$totalMedia/9', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
