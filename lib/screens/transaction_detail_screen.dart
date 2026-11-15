import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../app/app_router.dart';
import '../providers/transaction_provider.dart';
import '../services/moment_image_service.dart';
import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';
import '../widgets/moment_image.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MomentImageService _momentImages = MomentImageService();

  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _transactionRef {
    final uid = _uid;

    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(widget.transactionId);
  }

  CollectionReference<Map<String, dynamic>> _collection(String name) {
    return _db.collection('users').doc(_uid!).collection(name);
  }

  int _amount(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString().replaceAll('.', '') ?? '') ?? 0;
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  String _dateText(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }

  String _timeText(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _categoryName(Map<String, dynamic> data) {
    final saved = data['categoryName']?.toString().trim() ?? '';

    if (saved.isNotEmpty) return saved;

    const names = <String, String>{
      'food': 'Ăn',
      'drink': 'Uống',
      'transport': 'Di chuyển',
      'shopping': 'Mua sắm',
      'other': 'Khác',
      'salary': 'Lương',
      'bonus': 'Thưởng',
      'other_income': 'Thu nhập khác',
    };

    return names[data['categoryId']] ?? 'Giao dịch';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. MỞ HỘP THOẠI CHỈNH SỬA
  // ==========================================

  Future<void> _editTransaction(Map<String, dynamic> original) async {
    if (_busy || _uid == null) return;

    String? uploadedImageUrl;
    var transactionSaved = false;

    setState(() {
      _busy = true;
    });

    try {
      final results = await Future.wait([
        _collection('categories').get(),
        _collection('wallets').get(),
      ]);

      final categories = results[0].docs.map((doc) {
        return <String, dynamic>{...doc.data(), 'id': doc.id};
      }).toList();

      final wallets = results[1].docs.map((doc) {
        return <String, dynamic>{...doc.data(), 'id': doc.id};
      }).toList();

      if (!mounted) return;

      if (categories.isEmpty || wallets.isEmpty) {
        _showMessage('Chưa có danh mục hoặc ví để chỉnh sửa.');
        return;
      }

      // Dialog tự quản lý controller và vòng đời Widget.
      final changed = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return _TransactionEditDialog(
            original: original,
            categories: categories,
            wallets: wallets,
          );
        },
      );

      if (!mounted || changed == null) return;

      final oldImagePath = original['imagePath']?.toString();
      var newImagePath = changed['imagePath']?.toString();

      if (newImagePath != null &&
          !MomentImageService.isRemoteUrl(newImagePath)) {
        uploadedImageUrl = await _momentImages.upload(
          userId: _uid!,
          transactionId: widget.transactionId,
          localPath: newImagePath,
        );
        newImagePath = uploadedImageUrl;
        changed['imagePath'] = newImagePath;
      }

      await _saveEditedTransaction(changed);
      transactionSaved = true;

      try {
        await _momentImages.deleteIfReplaced(
          oldImageUrl: oldImagePath,
          newImageUrl: newImagePath,
        );
      } on FirebaseException catch (error) {
        _showMessage(
          'Đã lưu giao dịch nhưng chưa xóa được ảnh cũ: '
          '${error.message ?? error.code}',
        );
      } catch (error) {
        _showMessage('Đã lưu giao dịch nhưng chưa xóa được ảnh cũ: $error');
      }

      _showMessage('Đã cập nhật giao dịch và số dư ví.');
    } on FirebaseException catch (error) {
      if (!transactionSaved) await _cleanupUploadedImage(uploadedImageUrl);
      _showMessage('Lỗi Firebase: ${error.message ?? error.code}');
    } catch (error) {
      if (!transactionSaved) await _cleanupUploadedImage(uploadedImageUrl);
      _showMessage('Không thể chỉnh sửa: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _cleanupUploadedImage(String? imageUrl) async {
    try {
      await _momentImages.deleteImage(imageUrl);
    } on FirebaseException catch (error) {
      _showMessage(
        'Không thể xóa ảnh tải lên chưa được lưu: '
        '${error.message ?? error.code}',
      );
    }
  }

  // ==========================================
  // 2. LƯU CHỈNH SỬA VÀ CẬP NHẬT SỐ DƯ
  // ==========================================

  Future<void> _saveEditedTransaction(Map<String, dynamic> changed) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    await context.read<TransactionProvider>().updateTransactionWithWalletUpdate(
      uid,
      widget.transactionId,
      changed,
    );
  }

  // ==========================================
  // 3. XÓA GIAO DỊCH
  // ==========================================

  Future<void> _deleteTransaction() async {
    if (_busy || _uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa giao dịch?'),
          content: const Text(
            'Giao dịch sẽ bị xóa khỏi lịch sử '
            'và số dư ví sẽ được điều chỉnh lại. '
            'Bạn có chắc chắn muốn xóa?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _busy = true;
    });

    try {
      final imageUrl = await context
          .read<TransactionProvider>()
          .deleteTransactionWithWalletUpdate(_uid!, widget.transactionId);

      if (!mounted) return;

      try {
        await _momentImages.deleteRemote(imageUrl);
      } on FirebaseException catch (error) {
        _showMessage(
          'Đã xóa giao dịch nhưng chưa xóa được ảnh: '
          '${error.message ?? error.code}',
        );
      } catch (error) {
        _showMessage('Đã xóa giao dịch nhưng chưa xóa được ảnh: $error');
      }

      if (!mounted) return;
      context.go(AppRouter.home);
    } catch (error) {
      _showMessage('Không thể xóa giao dịch: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ==========================================
  // 4. GIAO DIỆN CHI TIẾT
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final ref = _transactionRef;

    if (ref == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết giao dịch')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Chi tiết giao dịch')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Không tải được giao dịch:\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text('Không tìm thấy giao dịch.'));
          }

          final data = snapshot.data!.data()!;
          final isIncome = data['type'] == 'income';
          final amount = _amount(data['amount']);
          final date = _date(data['date']);
          final category = _categoryName(data);

          final title = data['title']?.toString().trim() ?? '';
          final note = data['note']?.toString().trim() ?? '';
          final imagePath = data['imagePath']?.toString();

          final walletId = data['walletId']?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // THẺ SỐ TIỀN
              FinanceCard(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: isIncome
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFFEDD5),
                      child: Icon(
                        isIncome ? Icons.south_west : Icons.north_east,
                        size: 34,
                        color: isIncome ? AppColors.income : AppColors.expense,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isIncome ? 'Khoản thu' : 'Khoản chi',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${isIncome ? '+' : '-'}'
                      '${formatVnd(amount)}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: isIncome ? AppColors.income : AppColors.expense,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title.isNotEmpty
                          ? title
                          : note.isNotEmpty
                          ? note
                          : category,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              if (imagePath != null && imagePath.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child:
                      MomentImageService.isRemoteUrl(imagePath) ||
                          File(imagePath).existsSync()
                      ? SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: MomentImage(imagePath: imagePath),
                        )
                      : Container(
                          height: 100,
                          alignment: Alignment.center,
                          color: Theme.of(context).colorScheme.surface,
                          child: const Text(
                            'Không tìm thấy ảnh trên thiết bị này.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ],

              const SizedBox(height: 18),

              // THÔNG TIN CHI TIẾT
              FinanceCard(
                child: Column(
                  children: [
                    _detailRow('Mã giao dịch', widget.transactionId),
                    const Divider(),
                    _detailRow('Danh mục', category),
                    const Divider(),
                    _detailRow(
                      'Tên món / nội dung',
                      title.isEmpty ? 'Không có' : title,
                    ),
                    const Divider(),

                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: walletId.isEmpty
                          ? null
                          : _collection('wallets').doc(walletId).get(),
                      builder: (context, walletSnapshot) {
                        final walletName =
                            walletSnapshot.data?.data()?['name']?.toString() ??
                            (walletId.isEmpty ? 'Không xác định' : walletId);

                        return _detailRow('Ví', walletName);
                      },
                    ),

                    const Divider(),
                    _detailRow('Ngày', _dateText(date)),
                    const Divider(),
                    _detailRow('Giờ', _timeText(date)),
                    const Divider(),
                    _detailRow('Ghi chú', note.isEmpty ? 'Không có' : note),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // NÚT CHỈNH SỬA
              FilledButton.icon(
                onPressed: _busy ? null : () => _editTransaction(data),
                icon: const Icon(Icons.edit),
                label: const Text('Chỉnh sửa giao dịch'),
              ),

              const SizedBox(height: 10),

              // NÚT XÓA
              OutlinedButton.icon(
                onPressed: _busy ? null : _deleteTransaction,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text(
                  'Xóa giao dịch',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),

              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ============================================
// 5. HỘP THOẠI CHỈNH SỬA RIÊNG
// ============================================

class _TransactionEditDialog extends StatefulWidget {
  final Map<String, dynamic> original;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> wallets;

  const _TransactionEditDialog({
    required this.original,
    required this.categories,
    required this.wallets,
  });

  @override
  State<_TransactionEditDialog> createState() => _TransactionEditDialogState();
}

class _TransactionEditDialogState extends State<_TransactionEditDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late String _type;
  String? _categoryId;
  String? _walletId;
  String? _imagePath;
  late DateTime _chosenDate;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    final original = widget.original;

    _type = original['type'] == 'income' ? 'income' : 'expense';

    final amount = original['amount'];

    _amountController = TextEditingController(
      text: amount is num
          ? amount.toInt().toString()
          : amount?.toString() ?? '',
    );

    _titleController = TextEditingController(
      text: original['title']?.toString() ?? '',
    );
    _noteController = TextEditingController(
      text: original['note']?.toString() ?? '',
    );

    _categoryId = original['categoryId']?.toString();

    _walletId = original['walletId']?.toString();
    _imagePath = original['imagePath']?.toString();

    final rawDate = original['date'];

    if (rawDate is Timestamp) {
      _chosenDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      _chosenDate = rawDate;
    } else {
      _chosenDate = DateTime.now();
    }

    _ensureSelections();
  }

  @override
  void dispose() {
    // Controller được hủy cùng chính Dialog Widget.
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _availableCategories {
    return widget.categories.where((category) {
      return category['type'] == _type;
    }).toList();
  }

  void _ensureSelections() {
    final categories = _availableCategories;

    final categoryExists = categories.any(
      (category) => category['id'] == _categoryId,
    );

    if (!categoryExists) {
      _categoryId = categories.isEmpty
          ? null
          : categories.first['id'] as String;
    }

    final walletExists = widget.wallets.any(
      (wallet) => wallet['id'] == _walletId,
    );

    if (!walletExists) {
      _walletId = widget.wallets.isEmpty
          ? null
          : widget.wallets.first['id'] as String;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chosenDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày giao dịch',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _chosenDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _chosenDate.hour,
        _chosenDate.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_chosenDate),
      helpText: 'Chọn giờ giao dịch',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _chosenDate = DateTime(
        _chosenDate.year,
        _chosenDate.month,
        _chosenDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (picked == null || !mounted) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().microsecondsSinceEpoch}${path.extension(picked.path)}';
      final saved = await File(picked.path)
          .copy(path.join(appDir.path, fileName));

      setState(() => _imagePath = saved.path);
    } catch (error) {
      if (!mounted) return;
      if (error is PlatformException &&
          source == ImageSource.camera &&
          error.code.toLowerCase().contains('denied')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa có quyền camera. Hãy bật quyền Camera trong Cài đặt ứng dụng.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thể chọn ảnh: $error')));
    }
  }

  void _submit() {
    final amount = int.tryParse(
      _amountController.text.trim().replaceAll('.', ''),
    );

    if (amount == null || amount <= 0) {
      _showError('Số tiền phải lớn hơn 0.');
      return;
    }

    if (_categoryId == null) {
      _showError('Vui lòng chọn danh mục.');
      return;
    }

    if (_walletId == null) {
      _showError('Vui lòng chọn ví.');
      return;
    }

    final categoryMatches = _availableCategories.where(
      (category) => category['id'] == _categoryId,
    );

    if (categoryMatches.isEmpty) {
      _showError('Danh mục không hợp lệ.');
      return;
    }

    final categoryName =
        categoryMatches.first['name']?.toString() ?? 'Danh mục';

    // Trả dữ liệu cho màn Chi tiết.
    // Không ghi Firestore trực tiếp từ Dialog.
    Navigator.of(context).pop({
      'type': _type,
      'amount': amount,
      'categoryId': _categoryId,
      'categoryName': categoryName,
      'walletId': _walletId,
      'imagePath': _imagePath,
      'title': _titleController.text.trim(),
      'note': _noteController.text.trim(),
      'date': Timestamp.fromDate(_chosenDate),
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final categories = _availableCategories;

    return AlertDialog(
      title: const Text('Chỉnh sửa giao dịch'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // LOẠI GIAO DỊCH
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Loại giao dịch',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Chi tiêu')),
                  DropdownMenuItem(value: 'income', child: Text('Thu nhập')),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _type = value;
                    _categoryId = null;
                    _ensureSelections();
                  });
                },
              ),

              const SizedBox(height: 14),

              // SỐ TIỀN
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VNĐ)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 14),

              // DANH MỤC
              DropdownButtonFormField<String>(
                key: ValueKey('category_$_type'),
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category['id'] as String,
                    child: Text(
                      category['name']?.toString() ?? 'Danh mục',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryId = value;
                  });
                },
              ),

              const SizedBox(height: 14),

              // VÍ
              DropdownButtonFormField<String>(
                initialValue: _walletId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ví',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(),
                ),
                items: widget.wallets.map((wallet) {
                  return DropdownMenuItem<String>(
                    value: wallet['id'] as String,
                    child: Text(
                      wallet['name']?.toString() ?? 'Ví',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _walletId = value;
                  });
                },
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tên món / nội dung',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 14),

              // GHI CHÚ
              TextField(
                controller: _noteController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 14),

              if (_imagePath != null && File(_imagePath!).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: MomentImage(imagePath: _imagePath!),
                  ),
                )
              else
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Chưa có ảnh khoảnh khắc.'),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh'),
                  ),
                  if (_imagePath != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _imagePath = null),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Gỡ ảnh'),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // NGÀY
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_formatDate(_chosenDate)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    '${_chosenDate.hour.toString().padLeft(2, '0')}:'
                    '${_chosenDate.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu thay đổi')),
      ],
    );
  }
}
