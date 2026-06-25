// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'management_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$teachersNotifierHash() => r'5acb66974b3c47e711897d8357baa25d0232de81';

/// See also [TeachersNotifier].
@ProviderFor(TeachersNotifier)
final teachersNotifierProvider =
    AutoDisposeAsyncNotifierProvider<TeachersNotifier, List<Teacher>>.internal(
  TeachersNotifier.new,
  name: r'teachersNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$teachersNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TeachersNotifier = AutoDisposeAsyncNotifier<List<Teacher>>;
String _$subjectsNotifierHash() => r'377697b3e672f3031556a8b3ef3eedc02cd5856a';

/// See also [SubjectsNotifier].
@ProviderFor(SubjectsNotifier)
final subjectsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SubjectsNotifier, List<Subject>>.internal(
  SubjectsNotifier.new,
  name: r'subjectsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subjectsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SubjectsNotifier = AutoDisposeAsyncNotifier<List<Subject>>;
String _$classroomsNotifierHash() =>
    r'0eb74684b22145f4bef55888fcf214b6c49e6a8a';

/// See also [ClassroomsNotifier].
@ProviderFor(ClassroomsNotifier)
final classroomsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    ClassroomsNotifier, List<Classroom>>.internal(
  ClassroomsNotifier.new,
  name: r'classroomsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$classroomsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ClassroomsNotifier = AutoDisposeAsyncNotifier<List<Classroom>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
