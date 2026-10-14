import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../data/ocr_providers.dart';
import '../data/ocr_service.dart';
import '../domain/ocr_state.dart';

/// OCR Text Reader screen — captures a still image from the ESP32-CAM and
/// reads any visible text aloud via TTS. Runs 100% on-device via ML Kit.
class TextReaderScreen extends ConsumerWidget {
  const TextReaderScreen({super.key});

  static const Color _border = Color(0xFF334155);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocrState = ref.watch(ocrProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Text Reader'),
        actions: [
          if (ocrState.result != null)
            IconButton(
              tooltip: 'Clear result',
              icon: const Icon(Icons.refresh, color: AppTheme.primaryAmber),
              onPressed: () => ref.read(ocrProvider.notifier).clearResult(),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildCaptureCard(context, ref, ocrState),
            if (ocrState.capturedBytes != null) ...[
              const SizedBox(height: 16),
              _buildImagePreview(ocrState),
            ],
            if (ocrState.errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(ocrState.errorMessage!),
            ],
            if (ocrState.result != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(context, ref, ocrState),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields, color: AppTheme.primaryAmber, size: 22),
              SizedBox(width: 8),
              Text(
                'OCR Text Reader',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.highContrastText,
                ),
              ),
              Spacer(),
              _OnDeviceBadge(),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Captures a still image from the ESP32-CAM and reads any visible text '
            'aloud — signage, product labels, menus, and documents. '
            'Recognition runs 100% on-device using Google ML Kit.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.secondaryText,
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.wifi, size: 14, color: AppTheme.warningOrange),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Requires phone connected to VisionAssist-Cap Wi-Fi.',
                  style: TextStyle(fontSize: 12, color: AppTheme.warningOrange),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureCard(
    BuildContext context,
    WidgetRef ref,
    OcrState state,
  ) {
    final phase = state.phase;
    final isLoading = state.isLoading;

    String phaseLabel;
    switch (phase) {
      case OcrPhase.capturing:
        phaseLabel = 'Capturing image…';
      case OcrPhase.processing:
        phaseLabel = 'Recognising text on-device…';
      default:
        phaseLabel = '';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          if (isLoading) ...[
            const LinearProgressIndicator(
              color: AppTheme.primaryAmber,
              backgroundColor: Color(0xFF334155),
            ),
            const SizedBox(height: 12),
            Text(
              phaseLabel,
              style: const TextStyle(
                color: AppTheme.primaryAmber,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
          ],
          AccessibleButton(
            label: isLoading ? 'Reading…' : 'Capture & Read Text',
            icon: isLoading ? Icons.hourglass_top : Icons.document_scanner,
            isPrimary: true,
            customColor: AppTheme.primaryAmber,
            customTextColor: Colors.black,
            onPressed: isLoading
                ? null
                : () => ref.read(ocrProvider.notifier).captureAndRead(),
          ),
          const SizedBox(height: 10),
          const Text(
            'Point the ESP32-CAM at text and tap to read.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(OcrState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.image, color: AppTheme.accentCyan, size: 18),
                SizedBox(width: 6),
                Text(
                  'Captured Image',
                  style: TextStyle(
                    color: AppTheme.highContrastText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Image.memory(
            state.capturedBytes!,
            fit: BoxFit.contain,
            width: double.infinity,
            gaplessPlayback: true,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x22FF5252),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.highContrastText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    WidgetRef ref,
    OcrState state,
  ) {
    final result = state.result!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isEmpty ? _border : AppTheme.successGreen,
          width: result.isEmpty ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isEmpty ? Icons.hide_image_outlined : Icons.check_circle,
                color: result.isEmpty
                    ? AppTheme.secondaryText
                    : AppTheme.successGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.isEmpty ? 'No Text Found' : 'Text Detected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: result.isEmpty
                      ? AppTheme.secondaryText
                      : AppTheme.successGreen,
                ),
              ),
              const Spacer(),
              if (!result.isEmpty)
                Text(
                  result.summary,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryText,
                  ),
                ),
            ],
          ),
          if (!result.isEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 12),
            // Display each detected text block
            ...result.blocks.asMap().entries.map(
              (e) => _TextBlockTile(
                blockIndex: e.key + 1,
                block: e.value,
                onSpeak: () =>
                    ref.read(ocrProvider.notifier).speakBlock(e.value),
              ),
            ),
            const SizedBox(height: 16),
            // TTS & Clipboard Controls
            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    label: 'Read Aloud',
                    icon: Icons.volume_up,
                    isPrimary: true,
                    customColor: AppTheme.primaryAmber,
                    customTextColor: Colors.black,
                    onPressed: () =>
                        ref.read(ocrProvider.notifier).speakResult(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copy all text',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.copy, color: AppTheme.accentCyan, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.rawText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recognized text copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                      foregroundColor: AppTheme.secondaryText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Stop'),
                    onPressed: () =>
                        ref.read(ocrProvider.notifier).stopSpeaking(),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'The camera could not detect readable text in this image.\n'
              'Try moving closer to text, improving lighting, or holding the camera steadier.',
              style: TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TextBlockTile extends StatelessWidget {
  final int blockIndex;
  final dynamic block;
  final VoidCallback onSpeak;

  const _TextBlockTile({
    required this.blockIndex,
    required this.block,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final isSafety = block.category == OcrCategory.safety;
    final isCurrency = block.category == OcrCategory.currency;

    final Color badgeBg;
    final Color badgeText;
    final String categoryLabel;

    if (isSafety) {
      badgeBg = const Color(0x33FF5252);
      badgeText = AppTheme.errorRed;
      categoryLabel = 'SAFETY NOTICE';
    } else if (isCurrency) {
      badgeBg = const Color(0x3300E676);
      badgeText = AppTheme.successGreen;
      categoryLabel = 'CURRENCY';
    } else {
      badgeBg = const Color(0x2238BDF8);
      badgeText = AppTheme.accentCyan;
      categoryLabel = 'TEXT';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSafety ? AppTheme.errorRed.withValues(alpha: 0.6) : const Color(0xFF334155),
          width: isSafety ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSafety ? const Color(0xFF451A1A) : const Color(0xFF1E3A5F),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$blockIndex',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSafety ? AppTheme.errorRed : AppTheme.accentCyan,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  categoryLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: badgeText,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.volume_up, size: 18, color: AppTheme.primaryAmber),
                tooltip: 'Read block aloud',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: onSpeak,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            block.text as String,
            style: const TextStyle(
              color: AppTheme.highContrastText,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnDeviceBadge extends StatelessWidget {
  const _OnDeviceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x2200E676),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.successGreen, width: 1),
      ),
      child: const Text(
        'On-Device',
        style: TextStyle(
          color: AppTheme.successGreen,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
