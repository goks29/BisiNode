import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();
  Db? _db;
  DbCollection? _collection;
  String? _currentUsername;
  final String _source = "mongo_service.dart";

  factory MongoService() => _instance;
  MongoService._internal();

  Future<void> connect(String username) async {
    try {
      _currentUsername = username;

      final dbUri = dotenv.env['MONGODB_URI'];
      if (dbUri == null) throw Exception("MONGODB_URI tidak ditemukan di .env");

      if (_db != null) {
        await _db!.close();
      }

      _db = await Db.create(dbUri);
      await _db!.open().timeout(const Duration(seconds: 15)); 
      _collection = _db!.collection('shared_logs');

      await LogHelper.writeLog("DATABASE: Terhubung & Koleksi Siap", source: _source, level: 2);
    } catch (e) {
      await LogHelper.writeLog("DATABASE: Gagal Koneksi - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> _checkAndReconnect() async {
    if (_currentUsername == null) throw Exception("Username kosong");
  
    if (_db == null || !_db!.isConnected) {
      await LogHelper.writeLog("Koneksi mati/belum ada, mencoba reconnect...", source: _source);
      await connect(_currentUsername!);
    }
  }

  Future<List<LogModel>> getLogs() async {
    try {
      await _checkAndReconnect();
      final List<Map<String, dynamic>> data = await _collection!.find().toList();
      return data.map((json) => LogModel.fromMap(json)).toList(); 
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('ConnectionException')) {
        await connect(_currentUsername!);
        final List<Map<String, dynamic>> data = await _collection!.find().toList();
        return data.map((json) => LogModel.fromMap(json)).toList(); 
      }
      await LogHelper.writeLog("ERROR: Fetch Failed - $e", source: _source, level: 1);
      throw Exception("Gagal mengambil data dari Cloud: $e");
    }
  }

  Future<void> insertLog(LogModel log) async {
    try {
      await _checkAndReconnect();
      await _collection!.insertOne(log.toMap()); 
      await LogHelper.writeLog("SUCCESS: Data '${log.title}' Saved", source: _source, level: 2);
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('ConnectionException')) {
        await LogHelper.writeLog("Koneksi terputus saat insert. Melakukan Auto-Reconnect...", source: _source);
        await connect(_currentUsername!);
        await _collection!.insertOne(log.toMap());
        return; 
      }
      await LogHelper.writeLog("ERROR: Insert Failed - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> updateLog(LogModel log) async {
    try {
      await _checkAndReconnect();
      if (log.id == null) throw Exception("ID Log tidak ditemukan untuk update");

      await _collection!.replaceOne(where.id(ObjectId.fromHexString(log.id!)), log.toMap());
      await LogHelper.writeLog("DATABASE: Update '${log.title}' Berhasil", source: _source, level: 2);
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('ConnectionException')) {
        await connect(_currentUsername!);
        await _collection!.replaceOne(where.id(ObjectId.fromHexString(log.id!)), log.toMap());
        return;
      }
      await LogHelper.writeLog("DATABASE: Update Gagal - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> deleteLog(String id) async {
    try {
      await _checkAndReconnect();
      await _collection!.remove(where.id(ObjectId.fromHexString(id)));
      await LogHelper.writeLog("DATABASE: Hapus ID $id Berhasil", source: _source, level: 2);
    } catch (e) {
       if (e.toString().contains('SocketException') || e.toString().contains('ConnectionException')) {
        await connect(_currentUsername!);
        await _collection!.remove(where.id(ObjectId.fromHexString(id)));
        return;
      }
      await LogHelper.writeLog("DATABASE: Hapus Gagal - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      await LogHelper.writeLog("DATABASE: Koneksi ditutup", source: _source, level: 2);
    }
  }
}