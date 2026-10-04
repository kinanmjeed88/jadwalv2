// Frozen pre-weekly-load schema from b362b5c. Same persisted name and ID.
import 'package:isar/isar.dart';

class LegacyClassroom {
  Id id = Isar.autoIncrement;
  late String name;
  late String grade;
}

const LegacyClassroomSchema = CollectionSchema(
  name: r'Classroom',
  id: -8186663030834931469,
  properties: {
    r'grade': PropertySchema(
      id: 0,
      name: r'grade',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 1,
      name: r'name',
      type: IsarType.string,
    )
  },
  estimateSize: _classroomEstimateSize,
  serialize: _classroomSerialize,
  deserialize: _classroomDeserialize,
  deserializeProp: _classroomDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _classroomGetId,
  getLinks: _classroomGetLinks,
  attach: _classroomAttach,
  version: '3.1.0+1',
);

int _classroomEstimateSize(
  LegacyClassroom object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.grade.length * 3;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _classroomSerialize(
  LegacyClassroom object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.grade);
  writer.writeString(offsets[1], object.name);
}

LegacyClassroom _classroomDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LegacyClassroom();
  object.grade = reader.readString(offsets[0]);
  object.id = id;
  object.name = reader.readString(offsets[1]);
  return object;
}

P _classroomDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _classroomGetId(LegacyClassroom object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _classroomGetLinks(LegacyClassroom object) {
  return [];
}

void _classroomAttach(IsarCollection<dynamic> col, Id id, LegacyClassroom object) {
  object.id = id;
}

