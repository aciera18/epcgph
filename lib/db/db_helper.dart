import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  // -------------------- DATABASE INIT --------------------
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'epcgph.db');

    return await openDatabase(
      path,
      version: 5, // incremented from 4 → 5
      onCreate: (db, version) async {
        // 🟢 Logins table
        await db.execute('''
          CREATE TABLE logins(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            empno TEXT UNIQUE,
            username TEXT,
            password TEXT,
            mpin TEXT,
            seqnum TEXT,
            saved_date TEXT
          )
        ''');

        // 🟢 Profiles table
        await db.execute('''
          CREATE TABLE profiles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            empno TEXT UNIQUE,
            full_name TEXT,
            rank TEXT,
            unit TEXT,
            m_unit TEXT,
            email TEXT,
            bdate TEXT,
            tin TEXT,
            gsis_id TEXT,
            hmdf_id TEXT,
            med_id TEXT,
            cellno TEXT,
            device_info TEXT,
            username TEXT,
            password TEXT
          )
        ''');

        // 🟢 Payslips table
        await db.execute('''
          CREATE TABLE payslips(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            empno TEXT,
            paydate TEXT,
            html TEXT,
            saved_date TEXT
          )
        ''');
      },

      // 🟣 Handle schema upgrades safely
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE logins ADD COLUMN seqnum TEXT');
        }
      },
    );
  }

  // -------------------- LOGIN FUNCTIONS --------------------
  static Future<void> saveLogin(
      String empno, String username, String password, String seqnum) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Preserve MPIN if exists
    final existing = await getLogin(empno);

    await db.insert(
      'logins',
      {
        'empno': empno,
        'username': username,
        'password': password,
        'mpin': existing != null ? existing['mpin'] : '',
        'seqnum': seqnum,
        'saved_date': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // Update MPIN locally
  static Future<void> updateMPIN(String empno, String mpin) async {
    final db = await database;
    await db.update(
      'logins',
      {'mpin': mpin},
      where: 'empno = ?',
      whereArgs: [empno],
    );
  }


  static Future<Map<String, dynamic>?> getLogin(String empno) async {
    final db = await database;
    final res = await db.query('logins', where: 'empno = ?', whereArgs: [empno]);
    return res.isNotEmpty ? res.first : null;
  }



  // 🟡 Get the most recent login (for auto-login or offline use)
  static Future<Map<String, dynamic>?> getLastLogin() async {
    final db = await database;
    final res = await db.query(
      'logins',
      orderBy: 'saved_date DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  static Future<void> cleanupExpiredLogins({int days = 30}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    await db.delete('logins', where: 'saved_date < ?', whereArgs: [cutoff]);
  }

  // -------------------- PROFILE FUNCTIONS --------------------
  static Future<void> saveProfile(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'profiles',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getProfile(String empno) async {
    final db = await database;
    final res = await db.query('profiles', where: 'empno = ?', whereArgs: [empno]);
    return res.isNotEmpty ? res.first : null;
  }

  // -------------------- PAYSLIP FUNCTIONS --------------------
  static Future<void> insertPayslip(String empno, String paydate, String html) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'payslips',
      {
        'empno': empno,
        'paydate': paydate,
        'html': html,
        'saved_date': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getPayslip(String empno, String paydate) async {
    final db = await database;
    final res = await db.query(
      'payslips',
      where: 'empno = ? AND paydate = ?',
      whereArgs: [empno, paydate],
    );
    return res.isNotEmpty ? res.first['html'] as String : null;
  }

  static Future<List<String>> getPaydates(String empno) async {
    final db = await database;
    final res = await db.query(
      'payslips',
      where: 'empno = ?',
      whereArgs: [empno],
      orderBy: 'paydate DESC',
    );
    return res.map((e) => e['paydate'].toString()).toList();
  }

  // -------------------- UTILITY --------------------
  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('logins');
    await db.delete('profiles');
    await db.delete('payslips');
  }
}
