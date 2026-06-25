import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/management/domain/repositories/management_repository.dart';
import '../../features/management/data/repositories/management_repository_impl.dart';
import 'database_provider.dart';

part 'repository_provider.g.dart';

@Riverpod(keepAlive: true)
Future<ManagementRepository> managementRepository(ManagementRepositoryRef ref) async {
  final isar = await ref.watch(isarDatabaseProvider.future);
  return ManagementRepositoryImpl(isar);
}
