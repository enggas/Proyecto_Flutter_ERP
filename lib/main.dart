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
      title: 'FinanzasPro',
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
  PullToRefreshController? pullToRefreshController;
  double progress = 0;

  // URL DE TU ERP EN LÍNEA
  final String erpUrl = "https://control-financiero-gamma.vercel.app/login";

  @override
  void initState() {
    super.initState();
    // Desliza hacia abajo para recargar la página
    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.blue),
      onRefresh: () => webViewController?.reload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // El botón atrás navega dentro del ERP; si no hay historial, cierra la app
        if (await webViewController?.canGoBack() ?? false) {
          webViewController?.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
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
                pullToRefreshController: pullToRefreshController,
                onWebViewCreated: (controller) {
                  webViewController = controller;
                },
                onLoadStop: (controller, url) {
                  pullToRefreshController?.endRefreshing();
                },
                onReceivedError: (controller, request, error) {
                  pullToRefreshController?.endRefreshing();
                },
                onProgressChanged: (controller, progressPercentage) {
                  if (progressPercentage == 100) {
                    pullToRefreshController?.endRefreshing();
                  }
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
        ),
      ),
    );
  }
}
