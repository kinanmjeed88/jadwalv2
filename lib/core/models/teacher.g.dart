// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTeacherCollection on Isar {
  IsarCollection<Teacher> get teachers => this.collection();
}

const TeacherSchema = CollectionSchema(
  name: r'Teacher',
  id: 356616661396274803,
  properties: {
    r'maxLessonsPerDay': PropertySchema(
      id: 0,
      name: r'maxLessonsPerDay',
      type: IsarType.long,
    ),
    r'maxLessonsPerWeek': PropertySchema(
      id: 1,
      name: r'maxLessonsPerWeek',
      type: IsarType.long,
    ),
    r'name': PropertySchema(
      id: 2,
      name: r'name',
      type: IsarType.string,
    ),
    r'specialization': PropertySchema(
      id: 3,
      name: r'specialization',
      type: IsarType.string,
    ),
    r'unavailableDays': PropertySchema(
      id: 4,
      name: r'unavailableDays',
      type: IsarType.longList,
    )
  },
  estimateSize: _teacherEstimateSize,
  serialize: _teacherSerialize,
  deserialize: _teacherDeserialize,
  deserializeProp: _teacherDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _teacherGetId,
  getLinks: _teacherGetLinks,
  attach: _teacherAttach,
  version: '3.1.0+1',
);

int _teacherEstimateSize(
  Teacher object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.specialization.length * 3;
  bytesCount += 3 + object.unavailableDays.length * 8;
  return bytesCount;
}

void _teacherSerialize(
  Teacher object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.maxLessonsPerDay);
  writer.writeLong(offsets[1], object.maxLessonsPerWeek);
  writer.writeString(offsets[2], object.name);
  writer.writeString(offsets[3], object.specialization);
  writer.writeLongList(offsets[4], object.unavailableDays);
}

Teacher _teacherDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Teacher();
  object.id = id;
  object.maxLessonsPerDay = reader.readLong(offsets[0]);
  object.maxLessonsPerWeek = reader.readLong(offsets[1]);
  object.name = reader.readString(offsets[2]);
  object.specialization = reader.readString(offsets[3]);
  object.unavailableDays = reader.readLongList(offsets[4]) ?? [];
  return object;
}

P _teacherDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLongList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _teacherGetId(Teacher object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _teacherGetLinks(Teacher object) {
  return [];
}

void _teacherAttach(IsarCollection<dynamic> col, Id id, Teacher object) {
  object.id = id;
}

extension TeacherQueryWhereSort on QueryBuilder<Teacher, Teacher, QWhere> {
  QueryBuilder<Teacher, Teacher, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TeacherQueryWhere on QueryBuilder<Teacher, Teacher, QWhereClause> {
  QueryBuilder<Teacher, Teacher, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension TeacherQueryFilter
    on QueryBuilder<Teacher, Teacher, QFilterCondition> {
  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> maxLessonsPerDayEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maxLessonsPerDay',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      maxLessonsPerDayGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maxLessonsPerDay',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      maxLessonsPerDayLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maxLessonsPerDay',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> maxLessonsPerDayBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maxLessonsPerDay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      maxLessonsPerWeekEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maxLessonsPerWeek',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      maxLessonsPerWeekGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maxLessonsPerWeek',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      maxLessonsPerWeekLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maxLessonsPerWeek',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      maxLessonsPerWeekBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maxLessonsPerWeek',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> specializationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'specialization',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      specializationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'specialization',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> specializationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'specialization',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> specializationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'specialization',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      specializationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'specialization',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> specializationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'specialization',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> specializationContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'specialization',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition> specializationMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'specialization',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      specializationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'specialization',
        value: '',
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      specializationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'specialization',
        value: '',
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unavailableDays',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unavailableDays',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unavailableDays',
        value: value,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unavailableDays',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'unavailableDays',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'unavailableDays',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'unavailableDays',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'unavailableDays',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'unavailableDays',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterFilterCondition>
      unavailableDaysLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'unavailableDays',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension TeacherQueryObject
    on QueryBuilder<Teacher, Teacher, QFilterCondition> {}

extension TeacherQueryLinks
    on QueryBuilder<Teacher, Teacher, QFilterCondition> {}

extension TeacherQuerySortBy on QueryBuilder<Teacher, Teacher, QSortBy> {
  QueryBuilder<Teacher, Teacher, QAfterSortBy> sortByMaxLessonsPerDay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLessonsPerDay', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> sortByMaxLessonsPerDayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLessonsPerDay', Sort.desc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> sortByMaxLessonsPerWeek() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLessonsPerWeek', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> sortByMaxLessonsPerWeekDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLessonsPerWeek', Sort.desc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> sortBySpecialization() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'specialization', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> sortBySpecializationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'specialization', Sort.desc);
    });
  }
}

extension TeacherQuerySortThenBy
    on QueryBuilder<Teacher, Teacher, QSortThenBy> {
  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenByMaxLessonsPerDay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLessonsPerDay', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenByMaxLessonsPerDayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLessonsPerDay', Sort.desc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenByMaxLessonsPerWeek() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLessonsPerWeek', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenByMaxLessonsPerWeekDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxLessonsPerWeek', Sort.desc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenBySpecialization() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'specialization', Sort.asc);
    });
  }

  QueryBuilder<Teacher, Teacher, QAfterSortBy> thenBySpecializationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'specialization', Sort.desc);
    });
  }
}

extension TeacherQueryWhereDistinct
    on QueryBuilder<Teacher, Teacher, QDistinct> {
  QueryBuilder<Teacher, Teacher, QDistinct> distinctByMaxLessonsPerDay() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maxLessonsPerDay');
    });
  }

  QueryBuilder<Teacher, Teacher, QDistinct> distinctByMaxLessonsPerWeek() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maxLessonsPerWeek');
    });
  }

  QueryBuilder<Teacher, Teacher, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Teacher, Teacher, QDistinct> distinctBySpecialization(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'specialization',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Teacher, Teacher, QDistinct> distinctByUnavailableDays() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unavailableDays');
    });
  }
}

extension TeacherQueryProperty
    on QueryBuilder<Teacher, Teacher, QQueryProperty> {
  QueryBuilder<Teacher, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Teacher, int, QQueryOperations> maxLessonsPerDayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maxLessonsPerDay');
    });
  }

  QueryBuilder<Teacher, int, QQueryOperations> maxLessonsPerWeekProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maxLessonsPerWeek');
    });
  }

  QueryBuilder<Teacher, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Teacher, String, QQueryOperations> specializationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'specialization');
    });
  }

  QueryBuilder<Teacher, List<int>, QQueryOperations> unavailableDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unavailableDays');
    });
  }
}
