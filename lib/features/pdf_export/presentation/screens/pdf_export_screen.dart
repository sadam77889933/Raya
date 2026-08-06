import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/pdf_generator.dart';
import '../../../report_form/presentation/providers/report_form_provider.dart';
import '../../../report_form/presentation/widgets/step_indicator.dart';

enum _PdfStatus { idle, generating, ready, error }

class _PdfExportState {
  final _PdfStatus status;
  final String? pdfPath;
  final String? errorMessage;

  const _PdfExportState({
    this.status = _PdfStatus.idle,
    this.pdfPath,
    this.errorMessage,
  });
}

class _PdfExportNotifier extends StateNotifier<_PdfExportState> {
  _PdfExportNotifier() : super(const _PdfExportState());

  Future<void> generatePdf(dynamic report) async {
    state = const _PdfExportState(status: _PdfStatus.generating);
    try {
      final path = await PdfGenerator.instance.generate(report);
      state = _PdfExportState(status: _PdfStatus.ready, pdfPath: path);
    } catch (e) {
      state = _PdfExportState(
        status: _PdfStatus.error,
        errorMessage: 'تعذّر إنشاء التقرير: ${e.toString()}',
      );
    }
  }
}

final _pdfExportProvider =
    StateNotifierProvider.autoDispose<_PdfExportNotifier, _PdfExportState>(
  (ref) => _PdfExportNotifier(),
);

class PdfExportScreen extends ConsumerStatefulWidget {
  const PdfExportScreen({super.key});

  @override
  ConsumerState<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends ConsumerState<PdfExportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final report =
          ref.read(reportFormProvider.notifier).buildReport();
      ref.read(_pdfExportProvider.notifier).generatePdf(report);
    });
  }

  Future<void> _share(String path) async {
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'تقرير حلقة القرآن الكريم',
    );
  }

  Future<void> _preview(String path) async {
    await Printing.layoutPdf(
      onLayout: (_) async => File(path).readAsBytes(),
      name: 'تقرير الحلقة',
    );
  }

  void _startNew() {
    ref.read(reportFormProvider.notifier).reset();
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(_pdfExportProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير جاهز'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const StepIndicator(currentStep: 4, totalSteps: 4),
          Expanded(
            child: _buildBody(context, exportState, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    _PdfExportState state,
    ThemeData theme,
  ) {
    switch (state.status) {
      case _PdfStatus.idle:
      case _PdfStatus.generating:
        return _buildGenerating(theme);
      case _PdfStatus.ready:
        return _buildReady(context, state.pdfPath!, theme);
      case _PdfStatus.error:
        return _buildError(state.errorMessage!, theme);
    }
  }

  Widget _buildGenerating(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text('جاري إنشاء التقرير...',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'لحظة من فضلك',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReady(
    BuildContext context,
    String pdfPath,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 60,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppStrings.pdfCreatedSuccess,
            style: theme.textTheme.headlineSmall
                ?.copyWith(color: Colors.green.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'التقرير جاهز للمشاركة والحفظ',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const Spacer(),
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _share(pdfPath),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(AppStrings.shareReport),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _preview(pdfPath),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('معاينة PDF'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _startNew,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('تقرير جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildError(String message, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade400, size: 64),
          const SizedBox(height: 16),
          Text('تعذّر إنشاء التقرير',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              final report =
                  ref.read(reportFormProvider.notifier).buildReport();
              ref
                  .read(_pdfExportProvider.notifier)
                  .generatePdf(report);
            },
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}