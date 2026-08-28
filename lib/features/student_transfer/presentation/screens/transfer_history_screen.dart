import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/student_transfer.dart';
import '../providers/student_transfer_provider.dart';

/// سجل كل عمليات نقل الطالبات — قراءة فقط، بلا أي إمكانية تعديل أو حذف
/// (السجل التاريخي يبقى كما وقع دائماً).
class TransferHistoryScreen extends ConsumerStatefulWidget {
  /// عند تمرير قيمة (مشرفة مسجد)، تُعرض فقط عمليات هذا المسجد. عند تركها
  /// null (المشرف العام)، تُعرض كل عمليات النقل في كل المساجد.
  final String? restrictToMosqueId;

  const TransferHistoryScreen({super.key, this.restrictToMosqueId});

  @override
  ConsumerState<TransferHistoryScreen> createState() =>
      _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends ConsumerState<TransferHistoryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final mosqueId = widget.restrictToMosqueId;
    final transfersAsync = mosqueId != null
        ? ref.watch(mosqueTransferHistoryProvider(mosqueId))
        : ref.watch(allTransferHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('سجل انتقالات الطالبات'),
        backgroundColor: Colors.grey.shade100,
      ),
      body: transfersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('حدث خطأ: $err', style: const TextStyle(fontFamily: 'Tajawal')),
        ),
        data: (transfers) {
          final query = _searchQuery.trim();
          final filtered = query.isEmpty
              ? transfers
              : transfers.where((t) => t.studentName.contains(query)).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'ابحثي باسم الطالبة...',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            transfers.isEmpty
                                ? 'لا توجد عمليات نقل بعد'
                                : 'لا توجد نتائج',
                            style: TextStyle(
                                fontFamily: 'Tajawal', color: Colors.grey.shade400),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _TransferCard(transfer: filtered[i]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final StudentTransfer transfer;

  const _TransferCard({required this.transfer});

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  transfer.studentName,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${transfer.transferHijriMonth} ${transfer.transferHijriYear}هـ',
                  style: TextStyle(
                      fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade400, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'من: ${transfer.fromCircleName} – ${transfer.fromSchoolName} – ${transfer.fromMosqueName}',
                        style: TextStyle(
                            fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.subdirectory_arrow_left_rounded,
                        size: 13, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'إلى: ${transfer.toCircleName} – ${transfer.toSchoolName} – ${transfer.toMosqueName}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'نفّذتها: ${transfer.performedByName} · ${_timeAgo(transfer.performedAt)}',
                  style: TextStyle(
                      fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          if (transfer.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.edit_note_rounded, size: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'السبب: ${transfer.reason}',
                    style: TextStyle(
                        fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
