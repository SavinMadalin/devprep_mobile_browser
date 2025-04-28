import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import SystemChrome
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// --- Define Theme Colors ---
// Example: Using the gray colors you asked about previously
// Light Theme Colors (Adjust as needed)
const Color lightStatusBarColor = Color(0xFFF3F4F6); // gray-200
const Color lightNavBarColor = Color(0xFFF3F4F6); // gray-200
const Brightness lightStatusIconBrightness = Brightness.dark;
const Brightness lightNavIconBrightness = Brightness.dark;
const Color lightScaffoldBackground = Color(0xFFF3F4F6); // gray-200

// Dark Theme Colors (Adjust as needed)
const Color darkStatusBarColor = Color(0xFF1F2937); // gray-800
const Color darkNavBarColor = Color(0xFF1F2937); // gray-800
const Brightness darkStatusIconBrightness = Brightness.light;
const Brightness darkNavIconBrightness = Brightness.light;
const Color darkScaffoldBackground = Color(0xFF1F2937); // gray-800

// Helper function to set System UI based on theme
void _setSystemUIColors({required bool isDarkMode}) {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: isDarkMode ? darkStatusBarColor : lightStatusBarColor,
      statusBarIconBrightness:
          isDarkMode ? darkStatusIconBrightness : lightStatusIconBrightness,
      systemNavigationBarColor: isDarkMode ? darkNavBarColor : lightNavBarColor,
      systemNavigationBarIconBrightness:
          isDarkMode ? darkNavIconBrightness : lightNavIconBrightness,
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // --- Set INITIAL system bar styles (assuming light theme is default) ---
  _setSystemUIColors(isDarkMode: false); // Set for light theme initially

  // Set the platform instance for Android
  WebViewPlatform.instance = AndroidWebViewPlatform();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use ThemeProvider or similar if you want Flutter UI to react too,
    // otherwise, just set initial theme data.
    return MaterialApp(
      title: 'DevPrep',
      theme: ThemeData(
        // Set the default scaffold background (matches initial light theme)
        scaffoldBackgroundColor: lightScaffoldBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightStatusBarColor, // Use initial light color as seed
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // You might want a darkTheme defined as well if Flutter UI needs it
      // darkTheme: ThemeData(...)
      home: const MyHomePage(title: 'DevPrep'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasConnectivityError = false;
  bool _isDarkMode = false; // Assume default is light

  final String _initialUrl =
      // 'https://devprep--myproject-6969b.europe-west4.hosted.app/';
      'http://10.0.2.2:3000/';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    setState(() {
      _isLoading = true;
      _hasConnectivityError = false;
    });

    final WebViewController controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                /* ... */
              },
              onPageStarted: (String url) {
                if (!_isLoading) {
                  setState(() {
                    _isLoading = true;
                    _hasConnectivityError = false;
                  });
                }
              },
              onPageFinished: (String url) {
                if (!_hasConnectivityError) {
                  setState(() {
                    _isLoading = false;
                  });
                  // --- Optional: Query initial theme from web app ---
                  // You could potentially run JS here to get the web app's
                  // current theme and set the initial colors correctly,
                  // in case the web app defaults to dark mode sometimes.
                  _controller
                      .runJavaScriptReturningResult(
                        'window.getCurrentTheme()',
                      ) // Use window. for safety
                      .then((result) {
                        // runJavaScriptReturningResult might return the value wrapped in quotes
                        // e.g., "\"dark\"" or "\"light\"" or potentially null/undefined as a string "null"
                        print("JS getCurrentTheme result: $result");

                        // Default to light theme if result is unexpected
                        bool jsThemeIsDark = false;
                        if (result is String) {
                          // Handle potential wrapping quotes and case-insensitivity
                          String themeString =
                              result.replaceAll('"', '').toLowerCase();
                          jsThemeIsDark = (themeString == 'dark');
                        } else if (result == 'dark') {
                          // Direct comparison if it's not a string literal
                          jsThemeIsDark = true;
                        }

                        // --- Update Flutter state ONLY if it changed ---
                        if (mounted && _isDarkMode != jsThemeIsDark) {
                          print(
                            "Theme mismatch detected on load. JS: $jsThemeIsDark, Flutter: $_isDarkMode. Updating Flutter state.",
                          );
                          setState(() {
                            _isDarkMode = jsThemeIsDark;
                            // No need to call _setSystemUIColors here,
                            // the build method's AnnotatedRegion will handle it.
                          });
                        } else {
                          print(
                            "Initial theme sync: JS theme ($jsThemeIsDark) matches Flutter state ($_isDarkMode). No state change needed.",
                          );
                        }
                      })
                      .catchError((error) {
                        // Handle cases where the JS function might not exist or throws an error
                        print(
                          "Error calling getCurrentTheme in WebView: $error",
                        );
                        // Optionally set a default theme or log the error
                        // If it fails, the theme will remain as it was (initially light)
                      });
                }
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('''Page resource error: ...''');
                if (error.isForMainFrame == true ||
                    error.errorCode == -6 ||
                    error.errorCode == -2) {
                  setState(() {
                    _hasConnectivityError = true;
                    _isLoading = false;
                  });
                }
              },
              onNavigationRequest: (NavigationRequest request) {
                // Example: Prevent navigation to youtube
                if (request.url.startsWith('https://www.youtube.com/')) {
                  debugPrint('blocking navigation to ${request.url}');
                  return NavigationDecision.prevent; // Must return a decision
                }
                debugPrint('allowing navigation to ${request.url}');
                return NavigationDecision.navigate; // Must return a decision
              },
            ),
          )
          // --- Add Theme Change Channel ---
          ..addJavaScriptChannel(
            'ThemeChannel',
            onMessageReceived: (JavaScriptMessage message) {
              print("Theme message received: ${message.message}");
              bool newIsDark = message.message == 'dark';
              // --- Update the state variable ---
              if (mounted && _isDarkMode != newIsDark) {
                // Only update if changed
                setState(() {
                  _isDarkMode = newIsDark;
                });
              }
              // --- No need to call _setSystemUIColors here anymore ---
            },
          )
          ..addJavaScriptChannel(
            // Keep your existing Toaster channel
            'Toaster',
            onMessageReceived: (JavaScriptMessage message) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message.message)));
              }
            },
          )
          ..loadRequest(Uri.parse(_initialUrl));

    _controller = controller;
  }

  void _retryLoading() {
    setState(() {
      _isLoading = true;
      _hasConnectivityError = false;
    });
    // --- Ensure colors reset to default on retry ---
    _setSystemUIColors(isDarkMode: false); // Reset to default (light)
    _controller.loadRequest(Uri.parse(_initialUrl));
  }

  // --- Build Error Screen ---
  Widget _buildErrorScreen(BuildContext context) {
    // Use the current theme's background color
    final bgColor =
        _isDarkMode ? darkScaffoldBackground : lightScaffoldBackground;
    // Choose text/icon colors that contrast with the background
    final textColor = _isDarkMode ? Colors.white70 : Colors.black87;
    final subTextColor = _isDarkMode ? Colors.white54 : Colors.black54;
    final iconColor = _isDarkMode ? Colors.white54 : Colors.black54;

    return Container(
      color: bgColor, // Use dynamic background color
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 80,
                color: iconColor, // Use dynamic icon color
              ),
              const SizedBox(height: 20),
              Text(
                'Connection Error',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor, // Use dynamic text color
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Could not connect to DevPrep...',
                style: TextStyle(
                  fontSize: 16,
                  color: subTextColor,
                ), // Use dynamic subtext color
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _retryLoading,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, // Keep button text white
                  backgroundColor:
                      Colors.blueAccent, // Keep button color consistent
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Build Loading Indicator ---
  Widget _buildLoadingIndicator(BuildContext context) {
    // Use the current theme's background color
    final bgColor =
        _isDarkMode ? darkScaffoldBackground : lightScaffoldBackground;
    return Container(
      color: bgColor, // Use dynamic background color
      child: Center(
        child: CircularProgressIndicator(
          // Consider making the indicator color dynamic too if needed
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define the style dynamically based on the state
    final SystemUiOverlayStyle currentStyle = SystemUiOverlayStyle(
      statusBarColor: _isDarkMode ? darkStatusBarColor : lightStatusBarColor,
      statusBarIconBrightness:
          _isDarkMode ? darkStatusIconBrightness : lightStatusIconBrightness,
      systemNavigationBarColor:
          _isDarkMode ? darkNavBarColor : lightNavBarColor,
      systemNavigationBarIconBrightness:
          _isDarkMode ? darkNavIconBrightness : lightNavIconBrightness,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Wrap Scaffold body
      value: currentStyle,
      child: Scaffold(
        // Optional: You might want the Scaffold background to also change
        backgroundColor:
            _isDarkMode ? darkScaffoldBackground : lightScaffoldBackground,
        body: SafeArea(
          top: true,
          bottom: true,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              AnimatedOpacity(
                opacity: _isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child:
                    _isLoading
                        ? _buildLoadingIndicator(context)
                        : const SizedBox.shrink(),
              ),
              AnimatedOpacity(
                opacity: _hasConnectivityError ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child:
                    _hasConnectivityError
                        ? _buildErrorScreen(context)
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
