// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, ExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _weekNumberMeta = const VerificationMeta(
    'weekNumber',
  );
  @override
  late final GeneratedColumn<int> weekNumber = GeneratedColumn<int>(
    'weekNumber',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayNameMeta = const VerificationMeta(
    'dayName',
  );
  @override
  late final GeneratedColumn<String> dayName = GeneratedColumn<String>(
    'dayName',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseNameMeta = const VerificationMeta(
    'exerciseName',
  );
  @override
  late final GeneratedColumn<String> exerciseName = GeneratedColumn<String>(
    'exerciseName',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setsMeta = const VerificationMeta('sets');
  @override
  late final GeneratedColumn<int> sets = GeneratedColumn<int>(
    'sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<String> reps = GeneratedColumn<String>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'orderIndex',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<String> rpe = GeneratedColumn<String>(
    'rpe',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _warmupSetsMeta = const VerificationMeta(
    'warmupSets',
  );
  @override
  late final GeneratedColumn<String> warmupSets = GeneratedColumn<String>(
    'warmupSets',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0'),
  );
  static const VerificationMeta _restMeta = const VerificationMeta('rest');
  @override
  late final GeneratedColumn<String> rest = GeneratedColumn<String>(
    'rest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sub1Meta = const VerificationMeta('sub1');
  @override
  late final GeneratedColumn<String> sub1 = GeneratedColumn<String>(
    'sub1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sub2Meta = const VerificationMeta('sub2');
  @override
  late final GeneratedColumn<String> sub2 = GeneratedColumn<String>(
    'sub2',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _videoUrlMeta = const VerificationMeta(
    'videoUrl',
  );
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
    'videoUrl',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sub1VideoUrlMeta = const VerificationMeta(
    'sub1VideoUrl',
  );
  @override
  late final GeneratedColumn<String> sub1VideoUrl = GeneratedColumn<String>(
    'sub1VideoUrl',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sub2VideoUrlMeta = const VerificationMeta(
    'sub2VideoUrl',
  );
  @override
  late final GeneratedColumn<String> sub2VideoUrl = GeneratedColumn<String>(
    'sub2VideoUrl',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _programmeNameMeta = const VerificationMeta(
    'programmeName',
  );
  @override
  late final GeneratedColumn<String> programmeName = GeneratedColumn<String>(
    'programmeName',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    weekNumber,
    dayName,
    exerciseName,
    sets,
    reps,
    orderIndex,
    rpe,
    notes,
    warmupSets,
    rest,
    sub1,
    sub2,
    videoUrl,
    sub1VideoUrl,
    sub2VideoUrl,
    programmeName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('weekNumber')) {
      context.handle(
        _weekNumberMeta,
        weekNumber.isAcceptableOrUnknown(data['weekNumber']!, _weekNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_weekNumberMeta);
    }
    if (data.containsKey('dayName')) {
      context.handle(
        _dayNameMeta,
        dayName.isAcceptableOrUnknown(data['dayName']!, _dayNameMeta),
      );
    } else if (isInserting) {
      context.missing(_dayNameMeta);
    }
    if (data.containsKey('exerciseName')) {
      context.handle(
        _exerciseNameMeta,
        exerciseName.isAcceptableOrUnknown(
          data['exerciseName']!,
          _exerciseNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseNameMeta);
    }
    if (data.containsKey('sets')) {
      context.handle(
        _setsMeta,
        sets.isAcceptableOrUnknown(data['sets']!, _setsMeta),
      );
    } else if (isInserting) {
      context.missing(_setsMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('orderIndex')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['orderIndex']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('rpe')) {
      context.handle(
        _rpeMeta,
        rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('warmupSets')) {
      context.handle(
        _warmupSetsMeta,
        warmupSets.isAcceptableOrUnknown(data['warmupSets']!, _warmupSetsMeta),
      );
    }
    if (data.containsKey('rest')) {
      context.handle(
        _restMeta,
        rest.isAcceptableOrUnknown(data['rest']!, _restMeta),
      );
    }
    if (data.containsKey('sub1')) {
      context.handle(
        _sub1Meta,
        sub1.isAcceptableOrUnknown(data['sub1']!, _sub1Meta),
      );
    }
    if (data.containsKey('sub2')) {
      context.handle(
        _sub2Meta,
        sub2.isAcceptableOrUnknown(data['sub2']!, _sub2Meta),
      );
    }
    if (data.containsKey('videoUrl')) {
      context.handle(
        _videoUrlMeta,
        videoUrl.isAcceptableOrUnknown(data['videoUrl']!, _videoUrlMeta),
      );
    }
    if (data.containsKey('sub1VideoUrl')) {
      context.handle(
        _sub1VideoUrlMeta,
        sub1VideoUrl.isAcceptableOrUnknown(
          data['sub1VideoUrl']!,
          _sub1VideoUrlMeta,
        ),
      );
    }
    if (data.containsKey('sub2VideoUrl')) {
      context.handle(
        _sub2VideoUrlMeta,
        sub2VideoUrl.isAcceptableOrUnknown(
          data['sub2VideoUrl']!,
          _sub2VideoUrlMeta,
        ),
      );
    }
    if (data.containsKey('programmeName')) {
      context.handle(
        _programmeNameMeta,
        programmeName.isAcceptableOrUnknown(
          data['programmeName']!,
          _programmeNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      weekNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekNumber'],
      )!,
      dayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dayName'],
      )!,
      exerciseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exerciseName'],
      )!,
      sets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sets'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reps'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orderIndex'],
      )!,
      rpe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rpe'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      warmupSets: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warmupSets'],
      )!,
      rest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rest'],
      )!,
      sub1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub1'],
      )!,
      sub2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub2'],
      )!,
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}videoUrl'],
      )!,
      sub1VideoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub1VideoUrl'],
      )!,
      sub2VideoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub2VideoUrl'],
      )!,
      programmeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}programmeName'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class ExerciseRow extends DataClass implements Insertable<ExerciseRow> {
  final int id;
  final int weekNumber;
  final String dayName;
  final String exerciseName;
  final int sets;
  final String reps;
  final int orderIndex;
  final String rpe;
  final String notes;
  final String warmupSets;
  final String rest;
  final String sub1;
  final String sub2;
  final String videoUrl;
  final String sub1VideoUrl;
  final String sub2VideoUrl;
  final String programmeName;
  const ExerciseRow({
    required this.id,
    required this.weekNumber,
    required this.dayName,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.orderIndex,
    required this.rpe,
    required this.notes,
    required this.warmupSets,
    required this.rest,
    required this.sub1,
    required this.sub2,
    required this.videoUrl,
    required this.sub1VideoUrl,
    required this.sub2VideoUrl,
    required this.programmeName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['weekNumber'] = Variable<int>(weekNumber);
    map['dayName'] = Variable<String>(dayName);
    map['exerciseName'] = Variable<String>(exerciseName);
    map['sets'] = Variable<int>(sets);
    map['reps'] = Variable<String>(reps);
    map['orderIndex'] = Variable<int>(orderIndex);
    map['rpe'] = Variable<String>(rpe);
    map['notes'] = Variable<String>(notes);
    map['warmupSets'] = Variable<String>(warmupSets);
    map['rest'] = Variable<String>(rest);
    map['sub1'] = Variable<String>(sub1);
    map['sub2'] = Variable<String>(sub2);
    map['videoUrl'] = Variable<String>(videoUrl);
    map['sub1VideoUrl'] = Variable<String>(sub1VideoUrl);
    map['sub2VideoUrl'] = Variable<String>(sub2VideoUrl);
    map['programmeName'] = Variable<String>(programmeName);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      weekNumber: Value(weekNumber),
      dayName: Value(dayName),
      exerciseName: Value(exerciseName),
      sets: Value(sets),
      reps: Value(reps),
      orderIndex: Value(orderIndex),
      rpe: Value(rpe),
      notes: Value(notes),
      warmupSets: Value(warmupSets),
      rest: Value(rest),
      sub1: Value(sub1),
      sub2: Value(sub2),
      videoUrl: Value(videoUrl),
      sub1VideoUrl: Value(sub1VideoUrl),
      sub2VideoUrl: Value(sub2VideoUrl),
      programmeName: Value(programmeName),
    );
  }

  factory ExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseRow(
      id: serializer.fromJson<int>(json['id']),
      weekNumber: serializer.fromJson<int>(json['weekNumber']),
      dayName: serializer.fromJson<String>(json['dayName']),
      exerciseName: serializer.fromJson<String>(json['exerciseName']),
      sets: serializer.fromJson<int>(json['sets']),
      reps: serializer.fromJson<String>(json['reps']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      rpe: serializer.fromJson<String>(json['rpe']),
      notes: serializer.fromJson<String>(json['notes']),
      warmupSets: serializer.fromJson<String>(json['warmupSets']),
      rest: serializer.fromJson<String>(json['rest']),
      sub1: serializer.fromJson<String>(json['sub1']),
      sub2: serializer.fromJson<String>(json['sub2']),
      videoUrl: serializer.fromJson<String>(json['videoUrl']),
      sub1VideoUrl: serializer.fromJson<String>(json['sub1VideoUrl']),
      sub2VideoUrl: serializer.fromJson<String>(json['sub2VideoUrl']),
      programmeName: serializer.fromJson<String>(json['programmeName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'weekNumber': serializer.toJson<int>(weekNumber),
      'dayName': serializer.toJson<String>(dayName),
      'exerciseName': serializer.toJson<String>(exerciseName),
      'sets': serializer.toJson<int>(sets),
      'reps': serializer.toJson<String>(reps),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'rpe': serializer.toJson<String>(rpe),
      'notes': serializer.toJson<String>(notes),
      'warmupSets': serializer.toJson<String>(warmupSets),
      'rest': serializer.toJson<String>(rest),
      'sub1': serializer.toJson<String>(sub1),
      'sub2': serializer.toJson<String>(sub2),
      'videoUrl': serializer.toJson<String>(videoUrl),
      'sub1VideoUrl': serializer.toJson<String>(sub1VideoUrl),
      'sub2VideoUrl': serializer.toJson<String>(sub2VideoUrl),
      'programmeName': serializer.toJson<String>(programmeName),
    };
  }

  ExerciseRow copyWith({
    int? id,
    int? weekNumber,
    String? dayName,
    String? exerciseName,
    int? sets,
    String? reps,
    int? orderIndex,
    String? rpe,
    String? notes,
    String? warmupSets,
    String? rest,
    String? sub1,
    String? sub2,
    String? videoUrl,
    String? sub1VideoUrl,
    String? sub2VideoUrl,
    String? programmeName,
  }) => ExerciseRow(
    id: id ?? this.id,
    weekNumber: weekNumber ?? this.weekNumber,
    dayName: dayName ?? this.dayName,
    exerciseName: exerciseName ?? this.exerciseName,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    orderIndex: orderIndex ?? this.orderIndex,
    rpe: rpe ?? this.rpe,
    notes: notes ?? this.notes,
    warmupSets: warmupSets ?? this.warmupSets,
    rest: rest ?? this.rest,
    sub1: sub1 ?? this.sub1,
    sub2: sub2 ?? this.sub2,
    videoUrl: videoUrl ?? this.videoUrl,
    sub1VideoUrl: sub1VideoUrl ?? this.sub1VideoUrl,
    sub2VideoUrl: sub2VideoUrl ?? this.sub2VideoUrl,
    programmeName: programmeName ?? this.programmeName,
  );
  ExerciseRow copyWithCompanion(ExercisesCompanion data) {
    return ExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      weekNumber: data.weekNumber.present
          ? data.weekNumber.value
          : this.weekNumber,
      dayName: data.dayName.present ? data.dayName.value : this.dayName,
      exerciseName: data.exerciseName.present
          ? data.exerciseName.value
          : this.exerciseName,
      sets: data.sets.present ? data.sets.value : this.sets,
      reps: data.reps.present ? data.reps.value : this.reps,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      notes: data.notes.present ? data.notes.value : this.notes,
      warmupSets: data.warmupSets.present
          ? data.warmupSets.value
          : this.warmupSets,
      rest: data.rest.present ? data.rest.value : this.rest,
      sub1: data.sub1.present ? data.sub1.value : this.sub1,
      sub2: data.sub2.present ? data.sub2.value : this.sub2,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      sub1VideoUrl: data.sub1VideoUrl.present
          ? data.sub1VideoUrl.value
          : this.sub1VideoUrl,
      sub2VideoUrl: data.sub2VideoUrl.present
          ? data.sub2VideoUrl.value
          : this.sub2VideoUrl,
      programmeName: data.programmeName.present
          ? data.programmeName.value
          : this.programmeName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseRow(')
          ..write('id: $id, ')
          ..write('weekNumber: $weekNumber, ')
          ..write('dayName: $dayName, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('sets: $sets, ')
          ..write('reps: $reps, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rpe: $rpe, ')
          ..write('notes: $notes, ')
          ..write('warmupSets: $warmupSets, ')
          ..write('rest: $rest, ')
          ..write('sub1: $sub1, ')
          ..write('sub2: $sub2, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('sub1VideoUrl: $sub1VideoUrl, ')
          ..write('sub2VideoUrl: $sub2VideoUrl, ')
          ..write('programmeName: $programmeName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    weekNumber,
    dayName,
    exerciseName,
    sets,
    reps,
    orderIndex,
    rpe,
    notes,
    warmupSets,
    rest,
    sub1,
    sub2,
    videoUrl,
    sub1VideoUrl,
    sub2VideoUrl,
    programmeName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseRow &&
          other.id == this.id &&
          other.weekNumber == this.weekNumber &&
          other.dayName == this.dayName &&
          other.exerciseName == this.exerciseName &&
          other.sets == this.sets &&
          other.reps == this.reps &&
          other.orderIndex == this.orderIndex &&
          other.rpe == this.rpe &&
          other.notes == this.notes &&
          other.warmupSets == this.warmupSets &&
          other.rest == this.rest &&
          other.sub1 == this.sub1 &&
          other.sub2 == this.sub2 &&
          other.videoUrl == this.videoUrl &&
          other.sub1VideoUrl == this.sub1VideoUrl &&
          other.sub2VideoUrl == this.sub2VideoUrl &&
          other.programmeName == this.programmeName);
}

class ExercisesCompanion extends UpdateCompanion<ExerciseRow> {
  final Value<int> id;
  final Value<int> weekNumber;
  final Value<String> dayName;
  final Value<String> exerciseName;
  final Value<int> sets;
  final Value<String> reps;
  final Value<int> orderIndex;
  final Value<String> rpe;
  final Value<String> notes;
  final Value<String> warmupSets;
  final Value<String> rest;
  final Value<String> sub1;
  final Value<String> sub2;
  final Value<String> videoUrl;
  final Value<String> sub1VideoUrl;
  final Value<String> sub2VideoUrl;
  final Value<String> programmeName;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.weekNumber = const Value.absent(),
    this.dayName = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.sets = const Value.absent(),
    this.reps = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.rpe = const Value.absent(),
    this.notes = const Value.absent(),
    this.warmupSets = const Value.absent(),
    this.rest = const Value.absent(),
    this.sub1 = const Value.absent(),
    this.sub2 = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.sub1VideoUrl = const Value.absent(),
    this.sub2VideoUrl = const Value.absent(),
    this.programmeName = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required int weekNumber,
    required String dayName,
    required String exerciseName,
    required int sets,
    required String reps,
    required int orderIndex,
    this.rpe = const Value.absent(),
    this.notes = const Value.absent(),
    this.warmupSets = const Value.absent(),
    this.rest = const Value.absent(),
    this.sub1 = const Value.absent(),
    this.sub2 = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.sub1VideoUrl = const Value.absent(),
    this.sub2VideoUrl = const Value.absent(),
    this.programmeName = const Value.absent(),
  }) : weekNumber = Value(weekNumber),
       dayName = Value(dayName),
       exerciseName = Value(exerciseName),
       sets = Value(sets),
       reps = Value(reps),
       orderIndex = Value(orderIndex);
  static Insertable<ExerciseRow> custom({
    Expression<int>? id,
    Expression<int>? weekNumber,
    Expression<String>? dayName,
    Expression<String>? exerciseName,
    Expression<int>? sets,
    Expression<String>? reps,
    Expression<int>? orderIndex,
    Expression<String>? rpe,
    Expression<String>? notes,
    Expression<String>? warmupSets,
    Expression<String>? rest,
    Expression<String>? sub1,
    Expression<String>? sub2,
    Expression<String>? videoUrl,
    Expression<String>? sub1VideoUrl,
    Expression<String>? sub2VideoUrl,
    Expression<String>? programmeName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weekNumber != null) 'weekNumber': weekNumber,
      if (dayName != null) 'dayName': dayName,
      if (exerciseName != null) 'exerciseName': exerciseName,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (orderIndex != null) 'orderIndex': orderIndex,
      if (rpe != null) 'rpe': rpe,
      if (notes != null) 'notes': notes,
      if (warmupSets != null) 'warmupSets': warmupSets,
      if (rest != null) 'rest': rest,
      if (sub1 != null) 'sub1': sub1,
      if (sub2 != null) 'sub2': sub2,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (sub1VideoUrl != null) 'sub1VideoUrl': sub1VideoUrl,
      if (sub2VideoUrl != null) 'sub2VideoUrl': sub2VideoUrl,
      if (programmeName != null) 'programmeName': programmeName,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<int>? weekNumber,
    Value<String>? dayName,
    Value<String>? exerciseName,
    Value<int>? sets,
    Value<String>? reps,
    Value<int>? orderIndex,
    Value<String>? rpe,
    Value<String>? notes,
    Value<String>? warmupSets,
    Value<String>? rest,
    Value<String>? sub1,
    Value<String>? sub2,
    Value<String>? videoUrl,
    Value<String>? sub1VideoUrl,
    Value<String>? sub2VideoUrl,
    Value<String>? programmeName,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      weekNumber: weekNumber ?? this.weekNumber,
      dayName: dayName ?? this.dayName,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      orderIndex: orderIndex ?? this.orderIndex,
      rpe: rpe ?? this.rpe,
      notes: notes ?? this.notes,
      warmupSets: warmupSets ?? this.warmupSets,
      rest: rest ?? this.rest,
      sub1: sub1 ?? this.sub1,
      sub2: sub2 ?? this.sub2,
      videoUrl: videoUrl ?? this.videoUrl,
      sub1VideoUrl: sub1VideoUrl ?? this.sub1VideoUrl,
      sub2VideoUrl: sub2VideoUrl ?? this.sub2VideoUrl,
      programmeName: programmeName ?? this.programmeName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (weekNumber.present) {
      map['weekNumber'] = Variable<int>(weekNumber.value);
    }
    if (dayName.present) {
      map['dayName'] = Variable<String>(dayName.value);
    }
    if (exerciseName.present) {
      map['exerciseName'] = Variable<String>(exerciseName.value);
    }
    if (sets.present) {
      map['sets'] = Variable<int>(sets.value);
    }
    if (reps.present) {
      map['reps'] = Variable<String>(reps.value);
    }
    if (orderIndex.present) {
      map['orderIndex'] = Variable<int>(orderIndex.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<String>(rpe.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (warmupSets.present) {
      map['warmupSets'] = Variable<String>(warmupSets.value);
    }
    if (rest.present) {
      map['rest'] = Variable<String>(rest.value);
    }
    if (sub1.present) {
      map['sub1'] = Variable<String>(sub1.value);
    }
    if (sub2.present) {
      map['sub2'] = Variable<String>(sub2.value);
    }
    if (videoUrl.present) {
      map['videoUrl'] = Variable<String>(videoUrl.value);
    }
    if (sub1VideoUrl.present) {
      map['sub1VideoUrl'] = Variable<String>(sub1VideoUrl.value);
    }
    if (sub2VideoUrl.present) {
      map['sub2VideoUrl'] = Variable<String>(sub2VideoUrl.value);
    }
    if (programmeName.present) {
      map['programmeName'] = Variable<String>(programmeName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('weekNumber: $weekNumber, ')
          ..write('dayName: $dayName, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('sets: $sets, ')
          ..write('reps: $reps, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rpe: $rpe, ')
          ..write('notes: $notes, ')
          ..write('warmupSets: $warmupSets, ')
          ..write('rest: $rest, ')
          ..write('sub1: $sub1, ')
          ..write('sub2: $sub2, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('sub1VideoUrl: $sub1VideoUrl, ')
          ..write('sub2VideoUrl: $sub2VideoUrl, ')
          ..write('programmeName: $programmeName')
          ..write(')'))
        .toString();
  }
}

class $ExerciseLogsTable extends ExerciseLogs
    with TableInfo<$ExerciseLogsTable, ExerciseLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exerciseId',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userWeightMeta = const VerificationMeta(
    'userWeight',
  );
  @override
  late final GeneratedColumn<String> userWeight = GeneratedColumn<String>(
    'userWeight',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentTypeMeta = const VerificationMeta(
    'equipmentType',
  );
  @override
  late final GeneratedColumn<String> equipmentType = GeneratedColumn<String>(
    'equipmentType',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _userCommentsMeta = const VerificationMeta(
    'userComments',
  );
  @override
  late final GeneratedColumn<String> userComments = GeneratedColumn<String>(
    'userComments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _observedRpeMeta = const VerificationMeta(
    'observedRpe',
  );
  @override
  late final GeneratedColumn<String> observedRpe = GeneratedColumn<String>(
    'observedRpe',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exerciseId,
    userWeight,
    equipmentType,
    userComments,
    observedRpe,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exerciseId')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exerciseId']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('userWeight')) {
      context.handle(
        _userWeightMeta,
        userWeight.isAcceptableOrUnknown(data['userWeight']!, _userWeightMeta),
      );
    } else if (isInserting) {
      context.missing(_userWeightMeta);
    }
    if (data.containsKey('equipmentType')) {
      context.handle(
        _equipmentTypeMeta,
        equipmentType.isAcceptableOrUnknown(
          data['equipmentType']!,
          _equipmentTypeMeta,
        ),
      );
    }
    if (data.containsKey('userComments')) {
      context.handle(
        _userCommentsMeta,
        userComments.isAcceptableOrUnknown(
          data['userComments']!,
          _userCommentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userCommentsMeta);
    }
    if (data.containsKey('observedRpe')) {
      context.handle(
        _observedRpeMeta,
        observedRpe.isAcceptableOrUnknown(
          data['observedRpe']!,
          _observedRpeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_observedRpeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exerciseId'],
      )!,
      userWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}userWeight'],
      )!,
      equipmentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipmentType'],
      )!,
      userComments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}userComments'],
      )!,
      observedRpe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}observedRpe'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $ExerciseLogsTable createAlias(String alias) {
    return $ExerciseLogsTable(attachedDatabase, alias);
  }
}

class ExerciseLogRow extends DataClass implements Insertable<ExerciseLogRow> {
  final int id;
  final int exerciseId;
  final String userWeight;
  final String equipmentType;
  final String userComments;
  final String observedRpe;
  final String status;
  const ExerciseLogRow({
    required this.id,
    required this.exerciseId,
    required this.userWeight,
    required this.equipmentType,
    required this.userComments,
    required this.observedRpe,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exerciseId'] = Variable<int>(exerciseId);
    map['userWeight'] = Variable<String>(userWeight);
    map['equipmentType'] = Variable<String>(equipmentType);
    map['userComments'] = Variable<String>(userComments);
    map['observedRpe'] = Variable<String>(observedRpe);
    map['status'] = Variable<String>(status);
    return map;
  }

  ExerciseLogsCompanion toCompanion(bool nullToAbsent) {
    return ExerciseLogsCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      userWeight: Value(userWeight),
      equipmentType: Value(equipmentType),
      userComments: Value(userComments),
      observedRpe: Value(observedRpe),
      status: Value(status),
    );
  }

  factory ExerciseLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseLogRow(
      id: serializer.fromJson<int>(json['id']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      userWeight: serializer.fromJson<String>(json['userWeight']),
      equipmentType: serializer.fromJson<String>(json['equipmentType']),
      userComments: serializer.fromJson<String>(json['userComments']),
      observedRpe: serializer.fromJson<String>(json['observedRpe']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'userWeight': serializer.toJson<String>(userWeight),
      'equipmentType': serializer.toJson<String>(equipmentType),
      'userComments': serializer.toJson<String>(userComments),
      'observedRpe': serializer.toJson<String>(observedRpe),
      'status': serializer.toJson<String>(status),
    };
  }

  ExerciseLogRow copyWith({
    int? id,
    int? exerciseId,
    String? userWeight,
    String? equipmentType,
    String? userComments,
    String? observedRpe,
    String? status,
  }) => ExerciseLogRow(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    userWeight: userWeight ?? this.userWeight,
    equipmentType: equipmentType ?? this.equipmentType,
    userComments: userComments ?? this.userComments,
    observedRpe: observedRpe ?? this.observedRpe,
    status: status ?? this.status,
  );
  ExerciseLogRow copyWithCompanion(ExerciseLogsCompanion data) {
    return ExerciseLogRow(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      userWeight: data.userWeight.present
          ? data.userWeight.value
          : this.userWeight,
      equipmentType: data.equipmentType.present
          ? data.equipmentType.value
          : this.equipmentType,
      userComments: data.userComments.present
          ? data.userComments.value
          : this.userComments,
      observedRpe: data.observedRpe.present
          ? data.observedRpe.value
          : this.observedRpe,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseLogRow(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('userWeight: $userWeight, ')
          ..write('equipmentType: $equipmentType, ')
          ..write('userComments: $userComments, ')
          ..write('observedRpe: $observedRpe, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    exerciseId,
    userWeight,
    equipmentType,
    userComments,
    observedRpe,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseLogRow &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.userWeight == this.userWeight &&
          other.equipmentType == this.equipmentType &&
          other.userComments == this.userComments &&
          other.observedRpe == this.observedRpe &&
          other.status == this.status);
}

class ExerciseLogsCompanion extends UpdateCompanion<ExerciseLogRow> {
  final Value<int> id;
  final Value<int> exerciseId;
  final Value<String> userWeight;
  final Value<String> equipmentType;
  final Value<String> userComments;
  final Value<String> observedRpe;
  final Value<String> status;
  const ExerciseLogsCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.userWeight = const Value.absent(),
    this.equipmentType = const Value.absent(),
    this.userComments = const Value.absent(),
    this.observedRpe = const Value.absent(),
    this.status = const Value.absent(),
  });
  ExerciseLogsCompanion.insert({
    this.id = const Value.absent(),
    required int exerciseId,
    required String userWeight,
    this.equipmentType = const Value.absent(),
    required String userComments,
    required String observedRpe,
    required String status,
  }) : exerciseId = Value(exerciseId),
       userWeight = Value(userWeight),
       userComments = Value(userComments),
       observedRpe = Value(observedRpe),
       status = Value(status);
  static Insertable<ExerciseLogRow> custom({
    Expression<int>? id,
    Expression<int>? exerciseId,
    Expression<String>? userWeight,
    Expression<String>? equipmentType,
    Expression<String>? userComments,
    Expression<String>? observedRpe,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exerciseId': exerciseId,
      if (userWeight != null) 'userWeight': userWeight,
      if (equipmentType != null) 'equipmentType': equipmentType,
      if (userComments != null) 'userComments': userComments,
      if (observedRpe != null) 'observedRpe': observedRpe,
      if (status != null) 'status': status,
    });
  }

  ExerciseLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? exerciseId,
    Value<String>? userWeight,
    Value<String>? equipmentType,
    Value<String>? userComments,
    Value<String>? observedRpe,
    Value<String>? status,
  }) {
    return ExerciseLogsCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      userWeight: userWeight ?? this.userWeight,
      equipmentType: equipmentType ?? this.equipmentType,
      userComments: userComments ?? this.userComments,
      observedRpe: observedRpe ?? this.observedRpe,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (exerciseId.present) {
      map['exerciseId'] = Variable<int>(exerciseId.value);
    }
    if (userWeight.present) {
      map['userWeight'] = Variable<String>(userWeight.value);
    }
    if (equipmentType.present) {
      map['equipmentType'] = Variable<String>(equipmentType.value);
    }
    if (userComments.present) {
      map['userComments'] = Variable<String>(userComments.value);
    }
    if (observedRpe.present) {
      map['observedRpe'] = Variable<String>(observedRpe.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseLogsCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('userWeight: $userWeight, ')
          ..write('equipmentType: $equipmentType, ')
          ..write('userComments: $userComments, ')
          ..write('observedRpe: $observedRpe, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $ProgrammesTable extends Programmes
    with TableInfo<$ProgrammesTable, ProgrammeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgrammesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<String> importedAt = GeneratedColumn<String>(
    'importedAt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [name, importedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Programmes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgrammeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('importedAt')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['importedAt']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  ProgrammeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgrammeRow(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}importedAt'],
      )!,
    );
  }

  @override
  $ProgrammesTable createAlias(String alias) {
    return $ProgrammesTable(attachedDatabase, alias);
  }
}

class ProgrammeRow extends DataClass implements Insertable<ProgrammeRow> {
  final String name;
  final String importedAt;
  const ProgrammeRow({required this.name, required this.importedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['importedAt'] = Variable<String>(importedAt);
    return map;
  }

  ProgrammesCompanion toCompanion(bool nullToAbsent) {
    return ProgrammesCompanion(
      name: Value(name),
      importedAt: Value(importedAt),
    );
  }

  factory ProgrammeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgrammeRow(
      name: serializer.fromJson<String>(json['name']),
      importedAt: serializer.fromJson<String>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'importedAt': serializer.toJson<String>(importedAt),
    };
  }

  ProgrammeRow copyWith({String? name, String? importedAt}) => ProgrammeRow(
    name: name ?? this.name,
    importedAt: importedAt ?? this.importedAt,
  );
  ProgrammeRow copyWithCompanion(ProgrammesCompanion data) {
    return ProgrammeRow(
      name: data.name.present ? data.name.value : this.name,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgrammeRow(')
          ..write('name: $name, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, importedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgrammeRow &&
          other.name == this.name &&
          other.importedAt == this.importedAt);
}

class ProgrammesCompanion extends UpdateCompanion<ProgrammeRow> {
  final Value<String> name;
  final Value<String> importedAt;
  final Value<int> rowid;
  const ProgrammesCompanion({
    this.name = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgrammesCompanion.insert({
    required String name,
    required String importedAt,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       importedAt = Value(importedAt);
  static Insertable<ProgrammeRow> custom({
    Expression<String>? name,
    Expression<String>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (importedAt != null) 'importedAt': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgrammesCompanion copyWith({
    Value<String>? name,
    Value<String>? importedAt,
    Value<int>? rowid,
  }) {
    return ProgrammesCompanion(
      name: name ?? this.name,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (importedAt.present) {
      map['importedAt'] = Variable<String>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgrammesCompanion(')
          ..write('name: $name, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $ExerciseLogsTable exerciseLogs = $ExerciseLogsTable(this);
  late final $ProgrammesTable programmes = $ProgrammesTable(this);
  late final ExerciseDao exerciseDao = ExerciseDao(this as AppDatabase);
  late final ExerciseLogDao exerciseLogDao = ExerciseLogDao(
    this as AppDatabase,
  );
  late final ProgrammeDao programmeDao = ProgrammeDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    exercises,
    exerciseLogs,
    programmes,
  ];
}

typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      required int weekNumber,
      required String dayName,
      required String exerciseName,
      required int sets,
      required String reps,
      required int orderIndex,
      Value<String> rpe,
      Value<String> notes,
      Value<String> warmupSets,
      Value<String> rest,
      Value<String> sub1,
      Value<String> sub2,
      Value<String> videoUrl,
      Value<String> sub1VideoUrl,
      Value<String> sub2VideoUrl,
      Value<String> programmeName,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<int> weekNumber,
      Value<String> dayName,
      Value<String> exerciseName,
      Value<int> sets,
      Value<String> reps,
      Value<int> orderIndex,
      Value<String> rpe,
      Value<String> notes,
      Value<String> warmupSets,
      Value<String> rest,
      Value<String> sub1,
      Value<String> sub2,
      Value<String> videoUrl,
      Value<String> sub1VideoUrl,
      Value<String> sub2VideoUrl,
      Value<String> programmeName,
    });

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayName => $composableBuilder(
    column: $table.dayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sets => $composableBuilder(
    column: $table.sets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rest => $composableBuilder(
    column: $table.rest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sub1 => $composableBuilder(
    column: $table.sub1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sub2 => $composableBuilder(
    column: $table.sub2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sub1VideoUrl => $composableBuilder(
    column: $table.sub1VideoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sub2VideoUrl => $composableBuilder(
    column: $table.sub2VideoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programmeName => $composableBuilder(
    column: $table.programmeName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayName => $composableBuilder(
    column: $table.dayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sets => $composableBuilder(
    column: $table.sets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rest => $composableBuilder(
    column: $table.rest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sub1 => $composableBuilder(
    column: $table.sub1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sub2 => $composableBuilder(
    column: $table.sub2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sub1VideoUrl => $composableBuilder(
    column: $table.sub1VideoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sub2VideoUrl => $composableBuilder(
    column: $table.sub2VideoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programmeName => $composableBuilder(
    column: $table.programmeName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayName =>
      $composableBuilder(column: $table.dayName, builder: (column) => column);

  GeneratedColumn<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sets =>
      $composableBuilder(column: $table.sets, builder: (column) => column);

  GeneratedColumn<String> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rpe =>
      $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rest =>
      $composableBuilder(column: $table.rest, builder: (column) => column);

  GeneratedColumn<String> get sub1 =>
      $composableBuilder(column: $table.sub1, builder: (column) => column);

  GeneratedColumn<String> get sub2 =>
      $composableBuilder(column: $table.sub2, builder: (column) => column);

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<String> get sub1VideoUrl => $composableBuilder(
    column: $table.sub1VideoUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sub2VideoUrl => $composableBuilder(
    column: $table.sub2VideoUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get programmeName => $composableBuilder(
    column: $table.programmeName,
    builder: (column) => column,
  );
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          ExerciseRow,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (
            ExerciseRow,
            BaseReferences<_$AppDatabase, $ExercisesTable, ExerciseRow>,
          ),
          ExerciseRow,
          PrefetchHooks Function()
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> weekNumber = const Value.absent(),
                Value<String> dayName = const Value.absent(),
                Value<String> exerciseName = const Value.absent(),
                Value<int> sets = const Value.absent(),
                Value<String> reps = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> rpe = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> warmupSets = const Value.absent(),
                Value<String> rest = const Value.absent(),
                Value<String> sub1 = const Value.absent(),
                Value<String> sub2 = const Value.absent(),
                Value<String> videoUrl = const Value.absent(),
                Value<String> sub1VideoUrl = const Value.absent(),
                Value<String> sub2VideoUrl = const Value.absent(),
                Value<String> programmeName = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                weekNumber: weekNumber,
                dayName: dayName,
                exerciseName: exerciseName,
                sets: sets,
                reps: reps,
                orderIndex: orderIndex,
                rpe: rpe,
                notes: notes,
                warmupSets: warmupSets,
                rest: rest,
                sub1: sub1,
                sub2: sub2,
                videoUrl: videoUrl,
                sub1VideoUrl: sub1VideoUrl,
                sub2VideoUrl: sub2VideoUrl,
                programmeName: programmeName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int weekNumber,
                required String dayName,
                required String exerciseName,
                required int sets,
                required String reps,
                required int orderIndex,
                Value<String> rpe = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> warmupSets = const Value.absent(),
                Value<String> rest = const Value.absent(),
                Value<String> sub1 = const Value.absent(),
                Value<String> sub2 = const Value.absent(),
                Value<String> videoUrl = const Value.absent(),
                Value<String> sub1VideoUrl = const Value.absent(),
                Value<String> sub2VideoUrl = const Value.absent(),
                Value<String> programmeName = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                weekNumber: weekNumber,
                dayName: dayName,
                exerciseName: exerciseName,
                sets: sets,
                reps: reps,
                orderIndex: orderIndex,
                rpe: rpe,
                notes: notes,
                warmupSets: warmupSets,
                rest: rest,
                sub1: sub1,
                sub2: sub2,
                videoUrl: videoUrl,
                sub1VideoUrl: sub1VideoUrl,
                sub2VideoUrl: sub2VideoUrl,
                programmeName: programmeName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      ExerciseRow,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (
        ExerciseRow,
        BaseReferences<_$AppDatabase, $ExercisesTable, ExerciseRow>,
      ),
      ExerciseRow,
      PrefetchHooks Function()
    >;
typedef $$ExerciseLogsTableCreateCompanionBuilder =
    ExerciseLogsCompanion Function({
      Value<int> id,
      required int exerciseId,
      required String userWeight,
      Value<String> equipmentType,
      required String userComments,
      required String observedRpe,
      required String status,
    });
typedef $$ExerciseLogsTableUpdateCompanionBuilder =
    ExerciseLogsCompanion Function({
      Value<int> id,
      Value<int> exerciseId,
      Value<String> userWeight,
      Value<String> equipmentType,
      Value<String> userComments,
      Value<String> observedRpe,
      Value<String> status,
    });

class $$ExerciseLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseLogsTable> {
  $$ExerciseLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userWeight => $composableBuilder(
    column: $table.userWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userComments => $composableBuilder(
    column: $table.userComments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get observedRpe => $composableBuilder(
    column: $table.observedRpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseLogsTable> {
  $$ExerciseLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userWeight => $composableBuilder(
    column: $table.userWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userComments => $composableBuilder(
    column: $table.userComments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observedRpe => $composableBuilder(
    column: $table.observedRpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseLogsTable> {
  $$ExerciseLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userWeight => $composableBuilder(
    column: $table.userWeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equipmentType => $composableBuilder(
    column: $table.equipmentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userComments => $composableBuilder(
    column: $table.userComments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get observedRpe => $composableBuilder(
    column: $table.observedRpe,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$ExerciseLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseLogsTable,
          ExerciseLogRow,
          $$ExerciseLogsTableFilterComposer,
          $$ExerciseLogsTableOrderingComposer,
          $$ExerciseLogsTableAnnotationComposer,
          $$ExerciseLogsTableCreateCompanionBuilder,
          $$ExerciseLogsTableUpdateCompanionBuilder,
          (
            ExerciseLogRow,
            BaseReferences<_$AppDatabase, $ExerciseLogsTable, ExerciseLogRow>,
          ),
          ExerciseLogRow,
          PrefetchHooks Function()
        > {
  $$ExerciseLogsTableTableManager(_$AppDatabase db, $ExerciseLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<String> userWeight = const Value.absent(),
                Value<String> equipmentType = const Value.absent(),
                Value<String> userComments = const Value.absent(),
                Value<String> observedRpe = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => ExerciseLogsCompanion(
                id: id,
                exerciseId: exerciseId,
                userWeight: userWeight,
                equipmentType: equipmentType,
                userComments: userComments,
                observedRpe: observedRpe,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int exerciseId,
                required String userWeight,
                Value<String> equipmentType = const Value.absent(),
                required String userComments,
                required String observedRpe,
                required String status,
              }) => ExerciseLogsCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                userWeight: userWeight,
                equipmentType: equipmentType,
                userComments: userComments,
                observedRpe: observedRpe,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseLogsTable,
      ExerciseLogRow,
      $$ExerciseLogsTableFilterComposer,
      $$ExerciseLogsTableOrderingComposer,
      $$ExerciseLogsTableAnnotationComposer,
      $$ExerciseLogsTableCreateCompanionBuilder,
      $$ExerciseLogsTableUpdateCompanionBuilder,
      (
        ExerciseLogRow,
        BaseReferences<_$AppDatabase, $ExerciseLogsTable, ExerciseLogRow>,
      ),
      ExerciseLogRow,
      PrefetchHooks Function()
    >;
typedef $$ProgrammesTableCreateCompanionBuilder =
    ProgrammesCompanion Function({
      required String name,
      required String importedAt,
      Value<int> rowid,
    });
typedef $$ProgrammesTableUpdateCompanionBuilder =
    ProgrammesCompanion Function({
      Value<String> name,
      Value<String> importedAt,
      Value<int> rowid,
    });

class $$ProgrammesTableFilterComposer
    extends Composer<_$AppDatabase, $ProgrammesTable> {
  $$ProgrammesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgrammesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgrammesTable> {
  $$ProgrammesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgrammesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgrammesTable> {
  $$ProgrammesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );
}

class $$ProgrammesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgrammesTable,
          ProgrammeRow,
          $$ProgrammesTableFilterComposer,
          $$ProgrammesTableOrderingComposer,
          $$ProgrammesTableAnnotationComposer,
          $$ProgrammesTableCreateCompanionBuilder,
          $$ProgrammesTableUpdateCompanionBuilder,
          (
            ProgrammeRow,
            BaseReferences<_$AppDatabase, $ProgrammesTable, ProgrammeRow>,
          ),
          ProgrammeRow,
          PrefetchHooks Function()
        > {
  $$ProgrammesTableTableManager(_$AppDatabase db, $ProgrammesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgrammesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgrammesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgrammesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<String> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgrammesCompanion(
                name: name,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required String importedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProgrammesCompanion.insert(
                name: name,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgrammesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgrammesTable,
      ProgrammeRow,
      $$ProgrammesTableFilterComposer,
      $$ProgrammesTableOrderingComposer,
      $$ProgrammesTableAnnotationComposer,
      $$ProgrammesTableCreateCompanionBuilder,
      $$ProgrammesTableUpdateCompanionBuilder,
      (
        ProgrammeRow,
        BaseReferences<_$AppDatabase, $ProgrammesTable, ProgrammeRow>,
      ),
      ProgrammeRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$ExerciseLogsTableTableManager get exerciseLogs =>
      $$ExerciseLogsTableTableManager(_db, _db.exerciseLogs);
  $$ProgrammesTableTableManager get programmes =>
      $$ProgrammesTableTableManager(_db, _db.programmes);
}
