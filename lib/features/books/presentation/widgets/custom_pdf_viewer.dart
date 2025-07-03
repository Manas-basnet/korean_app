import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class CustomPdfViewer extends StatefulWidget {
  final String? pdfUrl;
  final String? pdfPath;
  final String? label;
  final double height;
  final VoidCallback? onError;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const CustomPdfViewer({
    super.key,
    this.pdfUrl,
    this.pdfPath,
    this.label,
    this.height = 400,
    this.onError,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CustomPdfViewer> createState() => _CustomPdfViewerState();
}

class _CustomPdfViewerState extends State<CustomPdfViewer> {
  PdfViewerController? _pdfViewerController;
  bool _isResolving = false;
  String? _resolvedPdfPath;
  String? _lastPdfPath;
  String? _lastPdfUrl;
  
  late String? pdfUrl;
  late String? pdfPath;
  late String? label;
  late double height;
  late VoidCallback? onError;
  late Widget Function(BuildContext, String)? placeholder;
  late Widget Function(BuildContext, String, dynamic)? errorWidget;

  @override
  void initState() {
    super.initState();
    _initializeStateVariables();
    _pdfViewerController = PdfViewerController();
    _resolvePdfSource();
  }

  @override
  void didUpdateWidget(CustomPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final oldPdfPath = pdfPath;
    final oldPdfUrl = pdfUrl;
    
    _initializeStateVariables();
    
    if (oldPdfPath != pdfPath || oldPdfUrl != pdfUrl) {
      _resolvePdfSource();
    }
  }
  
  void _initializeStateVariables() {
    pdfUrl = widget.pdfUrl;
    pdfPath = widget.pdfPath;
    label = widget.label;
    height = widget.height;
    onError = widget.onError;
    placeholder = widget.placeholder;
    errorWidget = widget.errorWidget;
  }

  Future<void> _resolvePdfSource() async {
    if (_isResolving) return;
    
    if (pdfPath == _lastPdfPath && pdfUrl == _lastPdfUrl && _resolvedPdfPath != null) {
      return;
    }
    
    setState(() {
      _isResolving = true;
    });
    
    try {
      final resolvedPath = await _determinePdfSource();
      
      if (mounted) {
        setState(() {
          _resolvedPdfPath = resolvedPath;
          _lastPdfPath = pdfPath;
          _lastPdfUrl = pdfUrl;
          _isResolving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvedPdfPath = null;
          _lastPdfPath = pdfPath;
          _lastPdfUrl = pdfUrl;
          _isResolving = false;
        });
        onError?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolving || _resolvedPdfPath == null) {
      return _buildLoadingWidget(context);
    }
    
    return _buildPdfViewer(context);
  }

  Future<String?> _determinePdfSource() async {
    if (pdfPath != null && pdfPath!.isNotEmpty) {
      final resolvedPath = await _resolvePdfPath(pdfPath!);
      if (resolvedPath != null) {
        final file = File(resolvedPath);
        if (await file.exists()) {
          return resolvedPath;
        }
      }
    }
    
    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      return pdfUrl;
    }
    
    return null;
  }

  Future<String?> _resolvePdfPath(String path) async {
    try {
      if (path.startsWith('/')) {
        if (await File(path).exists()) {
          return path;
        } else {
          return null;
        }
      }
      
      final documentsDir = await getApplicationDocumentsDirectory();
      final fullPath = '${documentsDir.path}/$path';
      
      if (await File(fullPath).exists()) {
        return fullPath;
      }
      
      final cacheDir = Directory('${documentsDir.path}/books_pdf_cache');
      final cachePath = '${cacheDir.path}/$path';
      
      if (await File(cachePath).exists()) {
        return cachePath;
      }
      
      return null;
      
    } catch (e) {
      return null;
    }
  }

  Widget _buildPdfViewer(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            if (label != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PDF',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLocalFile()
                  ? SfPdfViewer.file(
                      File(_resolvedPdfPath!),
                      controller: _pdfViewerController,
                      onDocumentLoadFailed: (details) {
                        onError?.call();
                      },
                    )
                  : SfPdfViewer.network(
                      _resolvedPdfPath!,
                      controller: _pdfViewerController,
                      onDocumentLoadFailed: (details) {
                        onError?.call();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLocalFile() {
    return _resolvedPdfPath != null && 
           (_resolvedPdfPath!.startsWith('/') || _resolvedPdfPath!.startsWith('file://'));
  }

  Widget _buildLoadingWidget(BuildContext context) {
    if (placeholder != null) {
      return placeholder!(context, 'Loading PDF...');
    }
    
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading PDF...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pdfViewerController?.dispose();
    super.dispose();
  }
}