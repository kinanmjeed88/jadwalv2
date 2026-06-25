// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSubjectCollection on Isar {
  IsarCollection<Subject> get subjects => this.collection();
}

const SubjectSchema = CollectionSchema(
  name: r'Subject',
  id: 7648000959054204885,
  properties: {
    r'lessonsPerWeek': PropertySchema(
      id: 0,
      name: r'lessonsPerWeek',
      type: IsarType.long,
    ),
    r'name': PropertySchema(
      id: 1,
      name: r'name',
      type: IsarType.string,
    ),
    r'preferEarlyPeriods': PropertySchema(
      id: 2,
      name: r'preferEarlyPeriods',
      type: IsarType.bool,
    )
  },
  estimateSize: _subjectEstimateSize,
  serialize: _subjectSerialize,
  deserialize: _subjectDeserialize,
  deserializeProp: _subjectDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _subjectGetId,
  getLinks: _subjectGetLinks,
  attach: _subjectAttach,
  version: '3.1.0+1',
);

int _subjectEstimateSize(
  Subject object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _subjectSerialize(
  Subject object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.lessonsPerWeek);
  writer.writeString(offsets[1], object.name);
  writer.writeBool(offsets[2], object.preferEarlyPeriods);
}

Subject _subjectDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Subject();
  object.id = id;
  object.lessonsPerWeek = reader.readLong(offsets[0]);
  object.name = reader.readString(offsets[1]);
  object.preferEarlyPeriods = reader.readBool(offsets[2]);
  return object;
}

P _subjectDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _subjectGetId(Subject object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _subjectGetLinks(Subject object) {
  return [];
}

void _subjectAttach(IsarCollection<dynamic> col, Id id, Subject object) {
  object.id = id;
}

extension SubjectQueryWhereSort on QueryBuilder<Subject, Subject, QWhere> {
  QueryBuilder<Subject, Subject, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SubjectQueryWhere on QueryBuilder<Subject, Subject, QWhereClause> {
  QueryBuilder<Subject, Subject, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Subject, Subject, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Subject, Subject, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Subject, Subject, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Subject, Subject, QAfterWhereClause> idBetween(
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

extension SubjectQueryFilter
    on QueryBuilder<Subject, Subject, QFilterCondition> {
  QueryBuilder<Subject, Subject, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Subject, Subject, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> lessonsPerWeekEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lessonsPerWeek',
        value: value,
      ));
    });
  }

  QueryBuilder<Subject, Subject, QAfterFilterCondition>
      lessonsPerWeekGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lessonsPerWeek',
        value: value,
      ));
    });
  }

  QueryBuilder<Subject, Subject, QAfterFilterCondition> lessonsPerWeekLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lessonsPerWeek',
        value: value,
      ));
    });
  }

  QueryBuilder<Subject, Subject, QAfterFilterCondition> lessonsPerWeekBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lessonsPerWeek',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameEqualTo(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameGreaterThan(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameLessThan(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameBetween(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameStartsWith(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameEndsWith(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameContains(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameMatches(
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

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Subject, Subject, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Subject, Subject, QAfterFilterCondition>
      preferEarlyPeriodsEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'preferEarlyPeriods',
        value: value,
      ));
    });
  }
}

extension SubjectQueryObject
    on QueryBuilder<Subject, Subject, QFilterCondition> {}

extension SubjectQueryLinks
    on QueryBuilder<Subject, Subject, QFilterCondition> {}

extension SubjectQuerySortBy on QueryBuilder<Subject, Subject, QSortBy> {
  QueryBuilder<Subject, Subject, QAfterSortBy> sortByLessonsPerWeek() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lessonsPerWeek', Sort.asc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> sortByLessonsPerWeekDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lessonsPerWeek', Sort.desc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> sortByPreferEarlyPeriods() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferEarlyPeriods', Sort.asc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> sortByPreferEarlyPeriodsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferEarlyPeriods', Sort.desc);
    });
  }
}

extension SubjectQuerySortThenBy
    on QueryBuilder<Subject, Subject, QSortThenBy> {
  QueryBuilder<Subject, Subject, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> thenByLessonsPerWeek() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lessonsPerWeek', Sort.asc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> thenByLessonsPerWeekDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lessonsPerWeek', Sort.desc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> thenByPreferEarlyPeriods() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferEarlyPeriods', Sort.asc);
    });
  }

  QueryBuilder<Subject, Subject, QAfterSortBy> thenByPreferEarlyPeriodsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferEarlyPeriods', Sort.desc);
    });
  }
}

extension SubjectQueryWhereDistinct
    on QueryBuilder<Subject, Subject, QDistinct> {
  QueryBuilder<Subject, Subject, QDistinct> distinctByLessonsPerWeek() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lessonsPerWeek');
    });
  }

  QueryBuilder<Subject, Subject, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Subject, Subject, QDistinct> distinctByPreferEarlyPeriods() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'preferEarlyPeriods');
    });
  }
}

extension SubjectQueryProperty
    on QueryBuilder<Subject, Subject, QQueryProperty> {
  QueryBuilder<Subject, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Subject, int, QQueryOperations> lessonsPerWeekProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lessonsPerWeek');
    });
  }

  QueryBuilder<Subject, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Subject, bool, QQueryOperations> preferEarlyPeriodsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'preferEarlyPeriods');
    });
  }
}
