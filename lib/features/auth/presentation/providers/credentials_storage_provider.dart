import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/credentials_storage_service.dart';

final credentialsStorageServiceProvider =
    Provider<CredentialsStorageService>(
  (ref) => CredentialsStorageService(),
);