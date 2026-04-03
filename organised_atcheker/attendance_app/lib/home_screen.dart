import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_model.dart';
import 'widgets/attendance_tile.dart';
import 'package:my_go_wrapper/my_go_wrapper.dart';
import 'updates.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String _statusMessage = "";
  bool _obscurePassword = true;
  List<AttendanceInfo> _attendanceData = [];

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('saved_username');
    final pass = prefs.getString('saved_password');
    final cachedData = prefs.getString('cached_attendance');

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        setState(() {
          _attendanceData = jsonList.map((e) => AttendanceInfo.fromJson(e)).toList();
        });
      } catch (e) {
        debugPrint('Error loading cached data: $e');
      }
    }

    if (user != null && pass != null) {
      setState(() {
        _usernameController.text = user;
        _passwordController.text = pass;
      });
      // Fetch new data every time
      _fetchAttendance();
    }
  }

  Future<void> _saveCredentials(String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_username', user);
    await prefs.setString('saved_password', pass);
  }

  Future<void> _fetchAttendance() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();
    
    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    // Check for updates first
    try {
      final updateInfo = await UpdateChecker.checkForUpdate();
      if (updateInfo != null && mounted) {
        final shouldUpdate = await _showUpdateDialog(updateInfo);
        if (shouldUpdate == true) {
          // If the user clicks update, we don't proceed with fetching attendance
          return;
        }
      }
    } catch (_) {
      // Ignore update errors and proceed
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Connecting to Samarth portal...";
    });
    
    // Periodically update status to show life
    final statusUpdateTimer = Stream.periodic(const Duration(seconds: 2)).listen((_) {
      if (mounted && _isLoading) {
        setState(() {
          if (_statusMessage.contains("Connecting")) {
            _statusMessage = "Logging in...";
          } else if (_statusMessage.contains("Logging")) {
            _statusMessage = "Scanning subjects...";
          } else if (_statusMessage.contains("Scanning")) {
            _statusMessage = "Fetching comprehensive data...";
          } else if (_statusMessage.contains("Fetching")) {
            _statusMessage = "Almost there, parsing records...";
          }
        });
      }
    });
    
    try {
      // Use Isolate.spawn() to run the FFI call in a background isolate WITHOUT
      // freezing the UI. We explicitly pass only plain Strings via SendPort so
      // no native handles (DynamicLibrary / function pointers) ever cross the
      // isolate boundary. The spawned isolate builds its own ScraperFFI instance.
      final String jsonString = await _runScraperInIsolate(user, pass);
      
      statusUpdateTimer.cancel();
      
      if (mounted) {
        setState(() {
          _statusMessage = "Processing results...";
        });
      }
      
      final dynamic decoded = jsonDecode(jsonString);
      
      // If the Go code returns an object with an error
      if (decoded is Map && decoded.containsKey('error')) {
        throw Exception(decoded['error']);
      }
      
      final List<dynamic> jsonList = decoded;
      
      if (mounted) {
        setState(() {
          _attendanceData = jsonList.map((e) => AttendanceInfo.fromJson(e)).toList();
        });
      }
      await _saveCredentials(user, pass);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_attendance', jsonString);
      
    } catch (e) {
      statusUpdateTimer.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/app_icon.png',
                height: 32,
                width: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Atchecker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // UPPER PART
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              )
            ),
            child: Column(
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _fetchAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _statusMessage,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          )
                        : const Text(
                            'Fetch Attendance',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
          
          // LOWER PART
          Expanded(
            child: _attendanceData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.fact_check_outlined, size: 60, color: Colors.blueGrey.shade200),
                         const SizedBox(height: 16),
                         Text(
                          'No attendance data.\nLogin to fetch.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16),
                        )
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _attendanceData.length,
                    itemBuilder: (context, index) {
                      return AttendanceTile(info: _attendanceData[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showUpdateDialog(UpdateInfo updateInfo) async {
    double downloadProgress = 0;
    bool isDownloading = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Update Available: ${updateInfo.latestVersion}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('A new version of Atchecker is available. Would you like to update?'),
                   const SizedBox(height: 12),
                   const Text('Release Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                   Text(updateInfo.releaseNotes),
                   if (isDownloading) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(value: downloadProgress),
                      const SizedBox(height: 8),
                      Text('${(downloadProgress * 100).toStringAsFixed(1)}%'),
                   ],
                ],
              ),
            ),
            actions: [
              if (!isDownloading) ...[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      isDownloading = true;
                    });
                    
                    await UpdateChecker.downloadAndInstallUpdate(
                      updateInfo.downloadUrl,
                      (progress) {
                        setState(() {
                          downloadProgress = progress;
                        });
                      },
                      (error) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Update failed: $error')),
                          );
                        }
                      },
                    );
                  },
                  child: const Text('Update Now'),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Downloading update...'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Isolate helpers — all must be top-level (no instance/closure captures)
// ---------------------------------------------------------------------------

/// Launches a background isolate and waits for the scraper result.
/// Only plain [String] values cross the isolate boundary via [SendPort],
/// so no native handles are ever serialized.
Future<String> _runScraperInIsolate(String username, String password) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(
    _scraperIsolateEntry,
    [receivePort.sendPort, username, password],
  );
  final result = await receivePort.first;
  receivePort.close();
  return result as String;
}

/// Entry point executed inside the spawned isolate.
/// Receives [args] = [SendPort, username, password].
void _scraperIsolateEntry(List<dynamic> args) {
  final sendPort = args[0] as SendPort;
  final username = args[1] as String;
  final password = args[2] as String;
  // ScraperFFI() here creates a FRESH instance local to this isolate
  // (Dart statics are per-isolate), so DynamicLibrary.open() is called
  // cleanly with no cross-boundary native pointers.
  final result = ScraperFFI().fetchAttendance(username, password);
  sendPort.send(result);
  Isolate.exit();
}
