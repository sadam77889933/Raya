import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/certificate_batch.dart';

/// حالة معالج إنشاء شهادة — شاشة واحدة بخمس خطوات داخلية (القسم ٢ من
/// تصميم الميزة): نوع المستفيد ← القالب ← المستفيدون ← معاينة ← الإنشاء.
class CertificateWizardState {
  final int step; // 0..4
  final CertificateRecipientType? recipientType;
  final String? templateId;
  // الدار المختارة يدوياً من المشرفة عند إصدار شهادات لمعلمات تحديداً —
  // غير مستخدَمة إطلاقاً لنوع "طالبات" (كل طالبة مرتبطة أصلاً بحلقة/دار
  // واحدة معروفة من سجلّها). المعلمة قد تُدرّس في أكثر من دار
  // (assignedSchoolIds قائمة لا قيمة واحدة)، فلا يوجد "دار افتراضية"
  // صحيحة تلقائياً — القرار متروك للمشرفة نفسها.
  final String? selectedSchoolId;
  final Set<String> selectedRecipientIds;
  final int previewIndex;
  final bool isGenerating;
  final String? error;

  const CertificateWizardState({
    this.step = 0,
    this.recipientType,
    this.templateId,
    this.selectedSchoolId,
    this.selectedRecipientIds = const {},
    this.previewIndex = 0,
    this.isGenerating = false,
    this.error,
  });

  CertificateWizardState copyWith({
    int? step,
    CertificateRecipientType? recipientType,
    bool clearTemplate = false,
    String? templateId,
    String? selectedSchoolId,
    bool clearSelectedSchoolId = false,
    Set<String>? selectedRecipientIds,
    int? previewIndex,
    bool? isGenerating,
    String? error,
    bool clearError = false,
  }) {
    return CertificateWizardState(
      step: step ?? this.step,
      recipientType: recipientType ?? this.recipientType,
      templateId: clearTemplate ? null : (templateId ?? this.templateId),
      selectedSchoolId: clearSelectedSchoolId
          ? null
          : (selectedSchoolId ?? this.selectedSchoolId),
      selectedRecipientIds:
          selectedRecipientIds ?? this.selectedRecipientIds,
      previewIndex: previewIndex ?? this.previewIndex,
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CertificateWizardNotifier extends StateNotifier<CertificateWizardState> {
  CertificateWizardNotifier() : super(const CertificateWizardState());

  void setRecipientType(CertificateRecipientType type) {
    state = state.copyWith(
      recipientType: type,
      clearTemplate: true,
      clearSelectedSchoolId: true,
      selectedRecipientIds: {},
    );
  }

  void setTemplate(String templateId) {
    state = state.copyWith(templateId: templateId);
  }

  /// تُستخدَم فقط عند إصدار شهادات لمعلمات — اختيار الدار يُبطل أي
  /// معلمات محدَّدات مسبقاً (قائمة المعلمات نفسها تتغيّر بتغيّر الدار).
  void setSelectedSchool(String? schoolId) {
    state = state.copyWith(
      selectedSchoolId: schoolId,
      clearSelectedSchoolId: schoolId == null,
      selectedRecipientIds: {},
    );
  }

  void toggleRecipient(String id) {
    final updated = Set<String>.from(state.selectedRecipientIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedRecipientIds: updated);
  }

  void setGroupSelected(List<String> ids, bool selected) {
    final updated = Set<String>.from(state.selectedRecipientIds);
    if (selected) {
      updated.addAll(ids);
    } else {
      updated.removeAll(ids);
    }
    state = state.copyWith(selectedRecipientIds: updated);
  }

  void setPreviewIndex(int index) {
    state = state.copyWith(previewIndex: index);
  }

  void goTo(int step) {
    state = state.copyWith(step: step, clearError: true);
  }

  void next() {
    state = state.copyWith(step: state.step + 1, clearError: true);
  }

  void back() {
    if (state.step == 0) return;
    state = state.copyWith(step: state.step - 1, clearError: true);
  }

  void setGenerating(bool value) {
    state = state.copyWith(isGenerating: value);
  }

  void setError(String message) {
    state = state.copyWith(isGenerating: false, error: message);
  }

  void reset() {
    state = const CertificateWizardState();
  }
}

/// autoDispose: حالة المعالج مؤقتة بطبيعتها (جلسة إنشاء واحدة)، فلا معنى
/// لإبقائها بعد مغادرة الشاشة.
final certificateWizardProvider = StateNotifierProvider.autoDispose<
    CertificateWizardNotifier, CertificateWizardState>(
  (ref) => CertificateWizardNotifier(),
);
