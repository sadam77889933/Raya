import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/pdf_merger_service.dart';

final pdfMergerServiceProvider = Provider<PdfMergerService>(
  (ref) => PdfMergerService(),
);