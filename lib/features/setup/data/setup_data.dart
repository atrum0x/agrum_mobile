/// GET /api/mobile/setup: what the phone keeps for working offline (FSD 5.4).
class SetupData {
  const SetupData({
    required this.today,
    required this.serverTime,
    required this.defaultEstateId,
    required this.estates,
    required this.workTypes,
    required this.collectionPoints,
    required this.workers,
    this.weighableToday = const [],
  });

  /// The server's date, yyyy-MM-dd.
  final String today;
  final DateTime serverTime;
  final String? defaultEstateId;
  final List<CachedEstate> estates;
  final List<CachedWorkType> workTypes;
  final List<CachedCollectionPoint> collectionPoints;
  final List<CachedWorker> workers;

  /// Today's attendance the server knows of that can be weighed (2.7).
  final List<CachedWeighable> weighableToday;

  factory SetupData.fromJson(Map<String, dynamic> json) {
    final attended = {...((json['attendedToday'] as List?) ?? const []).cast<String>()};
    List<Map<String, dynamic>> list(String key) => ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    return SetupData(
      today: json['today'] as String,
      serverTime: DateTime.parse(json['serverTime'] as String),
      defaultEstateId: json['defaultEstateId'] as String?,
      estates: list('estates').map(CachedEstate.fromJson).toList(),
      workTypes: list('workTypes').map(CachedWorkType.fromJson).toList(),
      collectionPoints: list('collectionPoints').map(CachedCollectionPoint.fromJson).toList(),
      workers: list('workers')
          .map((w) => CachedWorker.fromJson(w, attendedToday: attended.contains(w['employeeCode'])))
          .toList(),
      weighableToday: list('weighableToday').map(CachedWeighable.fromJson).toList(),
    );
  }
}

double? _decimal(Object? value) => value == null ? null : (value as num).toDouble();

/// An Active site the user can see.
class CachedEstate {
  const CachedEstate({
    required this.id,
    required this.name,
    required this.variancePercent,
    required this.maxDailyTransactions,
    this.fullDayQtyKg,
    this.halfDayQtyKg,
  });

  final String id;
  final String name;
  final double variancePercent;
  final int maxDailyTransactions;
  final double? fullDayQtyKg;
  final double? halfDayQtyKg;

  factory CachedEstate.fromJson(Map<String, dynamic> json) => CachedEstate(
        id: json['id'] as String,
        name: json['name'] as String,
        variancePercent: _decimal(json['variancePercent']) ?? 0,
        maxDailyTransactions: json['maxDailyTransactions'] as int,
        fullDayQtyKg: _decimal(json['fullDayQtyKg']),
        halfDayQtyKg: _decimal(json['halfDayQtyKg']),
      );

  factory CachedEstate.fromRow(Map<String, Object?> row) => CachedEstate(
        id: row['id'] as String,
        name: row['name'] as String,
        variancePercent: (row['variance_percent'] as num).toDouble(),
        maxDailyTransactions: row['max_daily_transactions'] as int,
        fullDayQtyKg: _decimal(row['full_day_qty_kg']),
        halfDayQtyKg: _decimal(row['half_day_qty_kg']),
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'variance_percent': variancePercent,
        'max_daily_transactions': maxDailyTransactions,
        'full_day_qty_kg': fullDayQtyKg,
        'half_day_qty_kg': halfDayQtyKg,
      };
}

class CachedWorkType {
  const CachedWorkType({required this.estateId, required this.workType, required this.weighingRequired});

  final String estateId;
  final String workType;
  final bool weighingRequired;

  factory CachedWorkType.fromJson(Map<String, dynamic> json) => CachedWorkType(
        estateId: json['estateId'] as String,
        workType: json['workType'] as String,
        weighingRequired: json['weighingRequired'] as bool? ?? false,
      );

  factory CachedWorkType.fromRow(Map<String, Object?> row) => CachedWorkType(
        estateId: row['estate_id'] as String,
        workType: row['work_type'] as String,
        weighingRequired: row['weighing_required'] == 1,
      );

  Map<String, Object?> toRow() => {
        'estate_id': estateId,
        'work_type': workType,
        'weighing_required': weighingRequired ? 1 : 0,
      };
}

class CachedCollectionPoint {
  const CachedCollectionPoint({required this.estateId, required this.cpCode, this.name, required this.isDefault});

  final String estateId;
  final String cpCode;
  final String? name;
  final bool isDefault;

  factory CachedCollectionPoint.fromJson(Map<String, dynamic> json) => CachedCollectionPoint(
        estateId: json['estateId'] as String,
        cpCode: json['cpCode'] as String,
        name: json['name'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  factory CachedCollectionPoint.fromRow(Map<String, Object?> row) => CachedCollectionPoint(
        estateId: row['estate_id'] as String,
        cpCode: row['cp_code'] as String,
        name: row['name'] as String?,
        isDefault: row['is_default'] == 1,
      );

  Map<String, Object?> toRow() => {
        'estate_id': estateId,
        'cp_code': cpCode,
        'name': name,
        'is_default': isDefault ? 1 : 0,
      };
}

/// An Active worker employed today, from any site, with the defaults the attendance form pre-fills.
class CachedWorker {
  const CachedWorker({
    required this.employeeCode,
    required this.fullName,
    this.defaultEstateId,
    this.homeEstateId,
    this.defaultCpCode,
    this.defaultCategory,
    required this.attendedToday,
  });

  final String employeeCode;
  final String fullName;
  final String? defaultEstateId;
  final String? homeEstateId;
  final String? defaultCpCode;

  /// REGULAR, SEASONAL, LENT or BORROWED; null when the employee has none.
  final String? defaultCategory;

  /// Already has attendance today on some site, as the server knew at the last refresh (AT-02).
  final bool attendedToday;

  factory CachedWorker.fromJson(Map<String, dynamic> json, {required bool attendedToday}) => CachedWorker(
        employeeCode: json['employeeCode'] as String,
        fullName: json['fullName'] as String,
        defaultEstateId: json['defaultEstateId'] as String?,
        homeEstateId: json['homeEstateId'] as String?,
        defaultCpCode: json['defaultCpCode'] as String?,
        defaultCategory: json['defaultCategory'] as String?,
        attendedToday: attendedToday,
      );

  factory CachedWorker.fromRow(Map<String, Object?> row) => CachedWorker(
        employeeCode: row['employee_code'] as String,
        fullName: row['full_name'] as String,
        defaultEstateId: row['default_estate_id'] as String?,
        homeEstateId: row['home_estate_id'] as String?,
        defaultCpCode: row['default_cp_code'] as String?,
        defaultCategory: row['default_category'] as String?,
        attendedToday: row['attended_today'] == 1,
      );

  Map<String, Object?> toRow() => {
        'employee_code': employeeCode,
        'full_name': fullName,
        'default_estate_id': defaultEstateId,
        'home_estate_id': homeEstateId,
        'default_cp_code': defaultCpCode,
        'default_category': defaultCategory,
        'attended_today': attendedToday ? 1 : 0,
      };
}

/// A worker with attendance today at one of the user's sites and a weighing-required work type, as
/// the server knew at the last refresh (GET /api/mobile/setup `weighableToday`).
class CachedWeighable {
  const CachedWeighable({
    required this.attendanceId,
    required this.employeeCode,
    required this.fullName,
    required this.estateId,
    required this.estateName,
    required this.cpCode,
    this.cpName,
    required this.workType,
    required this.variancePercent,
    required this.entriesToday,
    required this.dailyLimit,
    required this.lastSequence,
  });

  final String attendanceId;
  final String employeeCode;
  final String fullName;
  final String estateId;
  final String estateName;
  final String cpCode;
  final String? cpName;
  final String workType;
  final double variancePercent;

  /// Not counting cancelled weighings (WE-04).
  final int entriesToday;
  final int dailyLimit;

  /// Highest entry number so far, cancelled included.
  final int lastSequence;

  factory CachedWeighable.fromJson(Map<String, dynamic> json) => CachedWeighable(
        attendanceId: json['attendanceId'] as String,
        employeeCode: json['employeeCode'] as String,
        fullName: json['fullName'] as String,
        estateId: json['estateId'] as String,
        estateName: json['estateName'] as String,
        cpCode: json['cpCode'] as String,
        cpName: json['cpName'] as String?,
        workType: json['workType'] as String,
        variancePercent: _decimal(json['variancePercent']) ?? 0,
        entriesToday: json['entriesToday'] as int,
        dailyLimit: json['dailyLimit'] as int,
        lastSequence: json['lastSequence'] as int,
      );

  factory CachedWeighable.fromRow(Map<String, Object?> row) => CachedWeighable(
        attendanceId: row['attendance_id'] as String,
        employeeCode: row['employee_code'] as String,
        fullName: row['full_name'] as String,
        estateId: row['estate_id'] as String,
        estateName: row['estate_name'] as String,
        cpCode: row['cp_code'] as String,
        cpName: row['cp_name'] as String?,
        workType: row['work_type'] as String,
        variancePercent: (row['variance_percent'] as num).toDouble(),
        entriesToday: row['entries_today'] as int,
        dailyLimit: row['daily_limit'] as int,
        lastSequence: row['last_sequence'] as int,
      );

  Map<String, Object?> toRow() => {
        'attendance_id': attendanceId,
        'employee_code': employeeCode,
        'full_name': fullName,
        'estate_id': estateId,
        'estate_name': estateName,
        'cp_code': cpCode,
        'cp_name': cpName,
        'work_type': workType,
        'variance_percent': variancePercent,
        'entries_today': entriesToday,
        'daily_limit': dailyLimit,
        'last_sequence': lastSequence,
      };
}
