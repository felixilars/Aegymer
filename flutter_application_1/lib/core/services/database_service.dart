import 'package:flutter_application_1/core/databases/app_database.dart';

class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  final AppDatabase db = AppDatabase();
}