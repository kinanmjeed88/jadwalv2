// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLessonCollection on Isar {
  IsarCollection<Lesson> get lessons => this.collection();
}

const LessonSchema = CollectionSchema(
  name: r'Lesson',
  id: 6343151657775798464,
  properties: {
    r'dayIndex': PropertySchema(
      id: 0,
      name: r'dayIndex',
      type: IsarType.long,
    ),
    r'isPinned': PropertySchema(
      id: 1,
      name: r'isPinned',
      type: IsarType.bool,
    ),
    r'isUnassigned': PropertySchema(
      id: 2,
      name: r'isUnassigned',
      type: IsarType.bool,
    ),
    r'periodIndex': PropertySchema(
      id: 3,
      name: r'periodIndex',
      type: IsarType.long,
    )
  },
  estimateSize: _lessonEstimateSize,
  serialize: _lessonSerialize,
  deserialize: _lessonDeserialize,
  deserializeProp: _lessonDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {
    r'teacher': LinkSchema(
      id: 3080129896503402877,
      name: r'teacher',
      target: r'Teacher',
      single: true,
    ),
    r'subject': LinkSchema(
      id: -8608565202197394416,
      name: r'subject',
      target: r'Subject',
      single: true,
    ),
    r'classroom': LinkSchema(
      id: 9007159655472250381,
      name: r'classroom',
      target: r'Classroom',
      single: true,
    )
  },
  embeddedSchemas: {},
  getId: _lessonGetId,
  getLinks: _lessonGetLinks,
  attach: _lessonAttach,
  version: '3.1.0+1',
);

int _lessonEstimateSize(
  Lesson object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _lessonSerialize(
  Lesson object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.dayIndex);
  writer.writeBool(offsets[1], object.isPinned);
  writer.writeBool(offsets[2], object.isUnassigned);
  writer.writeLong(offsets[3], object.periodIndex);
}

Lesson _lessonDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Lesson();
  object.dayIndex = reader.readLongOrNull(offsets[0]);
  object.id = id;
  object.isPinned = reader.readBool(offsets[1]);
  object.periodIndex = reader.readLongOrNull(offsets[3]);
  return object;
}

P _lessonDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _lessonGetId(Lesson object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _lessonGetLinks(Lesson object) {
  return [object.teacher, object.subject, object.classroom];
}

void _lessonAttach(IsarCollection<dynamic> col, Id id, Lesson object) {
  object.id = id;
  object.teacher.attach(col, col.isar.collection<Teacher>(), r'teacher', id);
  object.subject.attach(col, col.isar.collection<Subject>(), r'subject', id);
  object.classroom
      .attach(col, col.isar.collection<Classroom>(), r'classroom', id);
}

extension LessonQueryWhereSort on QueryBuilder<Lesson, Lesson, QWhere> {
  QueryBuilder<Lesson, Lesson, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LessonQueryWhere on QueryBuilder<Lesson, Lesson, QWhereClause> {
  QueryBuilder<Lesson, Lesson, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Lesson, Lesson, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterWhereClause> idBetween(
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

extension LessonQueryFilter on QueryBuilder<Lesson, Lesson, QFilterCondition> {
  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> dayIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dayIndex',
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> dayIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dayIndex',
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> dayIndexEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dayIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> dayIndexGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dayIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> dayIndexLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dayIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> dayIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dayIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> isPinnedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isPinned',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> isUnassignedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isUnassigned',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> periodIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'periodIndex',
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> periodIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'periodIndex',
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> periodIndexEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'periodIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> periodIndexGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'periodIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> periodIndexLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'periodIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> periodIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'periodIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension LessonQueryObject on QueryBuilder<Lesson, Lesson, QFilterCondition> {}

extension LessonQueryLinks on QueryBuilder<Lesson, Lesson, QFilterCondition> {
  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> teacher(
      FilterQuery<Teacher> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'teacher');
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> teacherIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'teacher', 0, true, 0, true);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> subject(
      FilterQuery<Subject> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'subject');
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> subjectIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'subject', 0, true, 0, true);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> classroom(
      FilterQuery<Classroom> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'classroom');
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterFilterCondition> classroomIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'classroom', 0, true, 0, true);
    });
  }
}

extension LessonQuerySortBy on QueryBuilder<Lesson, Lesson, QSortBy> {
  QueryBuilder<Lesson, Lesson, QAfterSortBy> sortByDayIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dayIndex', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> sortByDayIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dayIndex', Sort.desc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> sortByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> sortByIsPinnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.desc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> sortByIsUnassigned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUnassigned', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> sortByIsUnassignedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUnassigned', Sort.desc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> sortByPeriodIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'periodIndex', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> sortByPeriodIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'periodIndex', Sort.desc);
    });
  }
}

extension LessonQuerySortThenBy on QueryBuilder<Lesson, Lesson, QSortThenBy> {
  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByDayIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dayIndex', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByDayIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dayIndex', Sort.desc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByIsPinnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPinned', Sort.desc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByIsUnassigned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUnassigned', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByIsUnassignedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUnassigned', Sort.desc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByPeriodIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'periodIndex', Sort.asc);
    });
  }

  QueryBuilder<Lesson, Lesson, QAfterSortBy> thenByPeriodIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'periodIndex', Sort.desc);
    });
  }
}

extension LessonQueryWhereDistinct on QueryBuilder<Lesson, Lesson, QDistinct> {
  QueryBuilder<Lesson, Lesson, QDistinct> distinctByDayIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dayIndex');
    });
  }

  QueryBuilder<Lesson, Lesson, QDistinct> distinctByIsPinned() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPinned');
    });
  }

  QueryBuilder<Lesson, Lesson, QDistinct> distinctByIsUnassigned() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isUnassigned');
    });
  }

  QueryBuilder<Lesson, Lesson, QDistinct> distinctByPeriodIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'periodIndex');
    });
  }
}

extension LessonQueryProperty on QueryBuilder<Lesson, Lesson, QQueryProperty> {
  QueryBuilder<Lesson, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Lesson, int?, QQueryOperations> dayIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dayIndex');
    });
  }

  QueryBuilder<Lesson, bool, QQueryOperations> isPinnedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPinned');
    });
  }

  QueryBuilder<Lesson, bool, QQueryOperations> isUnassignedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isUnassigned');
    });
  }

  QueryBuilder<Lesson, int?, QQueryOperations> periodIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'periodIndex');
    });
  }
}
