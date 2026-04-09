import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_model.dart';
import 'widgets/attendance_tile.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:my_go_wrapper/my_go_wrapper.dart';
import 'updates.dart';
import 'package:path_provider/path_provider.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _isDarkMode = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStoredData();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('is_dark_mode', _isDarkMode);
    });
  }

  Future<File> _getCacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/attendance_cache.json');
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('saved_username');
    final pass = prefs.getString('saved_password');

    // Clean up old bloated SharedPreferences cache
    if (prefs.containsKey('cached_attendance')) {
      await prefs.remove('cached_attendance');
      debugPrint('Removed old bloated SharedPreferences cache.');
    }

    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final cachedData = await file.readAsString();
        if (cachedData.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(cachedData);
          setState(() {
            _attendanceData = jsonList.map((e) => AttendanceInfo.fromJson(e)).toList();
            _sortAttendanceData();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cached data from file: $e');
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

    // Start update check in background (non-blocking)
    UpdateChecker.checkForUpdate().then((updateInfo) async {
      if (updateInfo != null && mounted) {
        final shouldUpdate = await _showUpdateDialog(updateInfo);
        if (shouldUpdate == true) {
          // If the user clicks update, we can cancel UI loading state
          setState(() {
            _isLoading = false;
            _statusMessage = 'Update initiated, attendance fetch cancelled.';
          });
        }
      }
    }).catchError((e) {
      // Silently ignore update errors
    });


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
          _sortAttendanceData();
        });
      }
      await _saveCredentials(user, pass);
      
      final file = await _getCacheFile();
      await file.writeAsString(jsonString);
      
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

  void _sortAttendanceData() {
    _attendanceData.sort((a, b) {
      final dateA = a.getParsedLatestDate();
      final dateB = b.getParsedLatestDate();
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // Put nulls at the end
      if (dateB == null) return -1;
      // Use dateB.compareTo(dateA) for descending (latest first)
      // If the user says it was backwards, I'll ensure it's actually dateB vs dateA
      return dateB.compareTo(dateA);
    });
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
            Text(
              'Atchecker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: const Color(0xFF2E7D32), // Green shade corresponding to Colors.green.shade800
                shadows: [
                  Shadow(
                    color: Colors.greenAccent.withValues(alpha: 0.8),
                    blurRadius: 12,
                    offset: const Offset(0, 0),
                  )
                ],
              ),
            ),
          ],
        ),
        elevation: 2,
        backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: _isDarkMode ? Colors.white : Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: _isDarkMode ? Colors.amber.shade400 : Colors.blueGrey.shade700,
            ),
            onPressed: _toggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: _isDarkMode ? const Color(0xFF121212) : Colors.grey.shade50,
        child: CustomScrollView(
          controller: _scrollController,
          primary: false,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // PARALLAX UPPER SECTION (Login + Wheel)
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _scrollController,
                builder: (context, child) {
                  double offset = 0;
                  if (_scrollController.hasClients && _scrollController.positions.length == 1) {
                    offset = _scrollController.offset;
                  }
                  
                  // Fade out the header as it scrolls up to prevent overlapping the list tiles
                  double opacity = 1.0 - (offset / 250.0);
                  if (opacity < 0.0) opacity = 0.0;
                  if (opacity > 1.0) opacity = 1.0;

                  // Parallax effect: moves slower than the scroll
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, offset * 0.5), 
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  // Absorbing vertical drags so swiping on the wheel/login area doesn't scroll the page
                  onVerticalDragStart: (_) {},
                  onVerticalDragUpdate: (_) {},
                  onVerticalDragEnd: (_) {},
                  onVerticalDragCancel: () {},
                  behavior: HitTestBehavior.translucent,
                  child: Column(
                    children: [
                      // Login Box
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: _isDarkMode ? Colors.black26 : Colors.blue.withValues(alpha: 0.05),
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
                              style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.grey),
                                prefixIcon: Icon(Icons.person_outline, color: _isDarkMode ? Colors.blueAccent : Colors.blueAccent),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Colors.blueAccent),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.grey),
                                prefixIcon: Icon(Icons.lock_outline, color: _isDarkMode ? Colors.blueAccent : Colors.blueAccent),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: _isDarkMode ? Colors.white54 : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Colors.blueAccent),
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
                      
                      // Attendance Wheel
                      if (_attendanceData.isNotEmpty)
                        AttendanceOverviewWheel(
                          attendanceData: _attendanceData, 
                          isDarkMode: _isDarkMode,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // LOWER TILES SECTION
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              sliver: _attendanceData.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             Icon(Icons.fact_check_outlined, size: 60, color: _isDarkMode ? Colors.white24 : Colors.blueGrey.shade200),
                             const SizedBox(height: 16),
                             Text(
                              'No attendance data.\nLogin to fetch.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _isDarkMode ? Colors.white54 : Colors.blueGrey.shade400, fontSize: 16),
                            )
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return AttendanceTile(
                            info: _attendanceData[index],
                            isDarkMode: _isDarkMode,
                          );
                        },
                        childCount: _attendanceData.length,
                      ),
                    ),
            ),
          ],
        ),
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
                    
                    final success = await UpdateChecker.downloadAndInstallUpdate(
                      updateInfo.downloadUrl,
                      (progress) {
                        setState(() {
                          downloadProgress = progress;
                        });
                      },
                      (error) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Update failed: $error')),
                          );
                        }
                      },
                    );

                    if (success && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Launching installer... Please follow the system prompts.'),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                  child: const Text('Update Now'),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: downloadProgress < 1.0 
                    ? const Text('Downloading update...')
                    : const Text('Launching installer...'),
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
  final errorPort = ReceivePort();
  Isolate? isolate;

  try {
    isolate = await Isolate.spawn(
      _scraperIsolateEntry,
      [receivePort.sendPort, username, password],
      onError: errorPort.sendPort,
      onExit: errorPort.sendPort,
    );

    final Object? result = await Future.any([
      receivePort.first,
      errorPort.first.then((error) {
        if (error == null) return "Isolate exited unexpectedly.";
        if (error is List) return "Isolate Error: ${error[0]}";
        return error.toString();
      }),
    ]);

    if (result is String && result.startsWith("Isolate Error")) {
      throw Exception(result);
    }
    if (result == "Isolate exited unexpectedly.") {
      throw Exception("Scraper aborted (Native Crash or Missing Library).");
    }

    return result as String;
  } finally {
    receivePort.close();
    errorPort.close();
    isolate?.kill(priority: Isolate.immediate);
  }
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

class AttendanceOverviewWheel extends StatefulWidget {
  final List<AttendanceInfo> attendanceData;
  final bool isDarkMode;

  const AttendanceOverviewWheel({
    super.key, 
    required this.attendanceData,
    this.isDarkMode = false,
  });

  @override
  State<AttendanceOverviewWheel> createState() => _AttendanceOverviewWheelState();
}

class _AttendanceOverviewWheelState extends State<AttendanceOverviewWheel> {
  int _touchedIndex = -1;

  Color _getColor(double percentage) {
    if (percentage >= 75) return Colors.green.shade500;
    if (percentage >= 60) return Colors.amber.shade400;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attendanceData.isEmpty) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      children: [
        // The Chart
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 45,
              sections: List.generate(widget.attendanceData.length, (i) {
                final isTouched = i == _touchedIndex;
                final info = widget.attendanceData[i];
                final radius = isTouched ? 45.0 : 35.0;
                
                double val = 0.0;
                if (info.attendancePercentage != 'N/A') {
                   val = double.tryParse(info.attendancePercentage.replaceAll('%', '')) ?? 0.0;
                }

                return PieChartSectionData(
                  color: _getColor(val),
                  value: 1,
                  title: '',
                  radius: radius,
                  badgeWidget: isTouched ? _buildTooltip(info) : null,
                  badgePositionPercentageOffset: 1.5,
                );
              }),
            ),
          ),
        ),
        
        // Center Logo
        Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35), // To keep the image perfectly circular if needed
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTooltip(AttendanceInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode ? Colors.black45 : Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 150),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.subjectName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Attendance: ${info.attendancePercentage}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
