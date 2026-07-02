import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ERP Corporativo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ErpWebViewScreen(),
    );
  }
}

class ErpWebViewScreen extends StatefulWidget {
  const ErpWebViewScreen({super.key});

  @override
  State<ErpWebViewScreen> createState() => _ErpWebViewScreenState();
}

class _ErpWebViewScreenState extends State<ErpWebViewScreen> {
  InAppWebViewController? webViewController;
  double progress = 0;
  
  // URL DE TU ERP EN LÍNEA
  final String erpUrl = "https://control-financiero-gamma.vercel.app/login"; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Puedes quitar el AppBar si quieres que el ERP ocupe TODA la pantalla
      appBar: AppBar(
        title: const Text('Mi ERP en Línea'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => webViewController?.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(erpUrl)),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              javaScriptEnabled: true, // Requerido para la mayoría de ERPs modernos
              domStorageEnabled: true, // Permite guardar sesiones/cookies locales
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onProgressChanged: (controller, progressPercentage) {
              setState(() {
                progress = progressPercentage / 100;
              });
            },
          ),
          // Barra de progreso que desaparece cuando la carga llega al 100%
          progress < 1.0
              ? LinearProgressIndicator(value: progress, color: Colors.blue)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}