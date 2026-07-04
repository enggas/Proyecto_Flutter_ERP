import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
    InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
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

class _ErpWebViewScreenState extends State<ErpWebViewScreen>
    with WidgetsBindingObserver {
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  double progress = 0;

  // URL DE TU ERP EN LÍNEA
  final String erpUrl = "https://control-financiero-gamma.vercel.app/login";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Desliza hacia abajo para recargar la página
    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.blue),
      onRefresh: () => webViewController?.reload(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Si el WebView queda sin repintar al volver del segundo plano (pantalla
  // negra), forzamos un repintado ligero al reanudar. No se pausa nada al
  // salir: pausar timers congelaba la carga de la página en MIUI.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (state == AppLifecycleState.resumed) {
      webViewController?.resumeTimers();
      setState(() {});
    }
  }

  // Retrocede dentro del ERP solo si la página anterior es real (evita caer
  // en la entrada vacía "about:blank" que deja la pantalla en blanco).
  Future<void> _retroceder() async {
    final controller = webViewController;
    if (controller != null) {
      final history = await controller.getCopyBackForwardList();
      final index = history?.currentIndex ?? 0;
      final list = history?.list ?? [];
      if (index > 0) {
        final urlAnterior = list[index - 1].url?.toString() ?? '';
        if (urlAnterior.startsWith('http')) {
          controller.goBack();
          return;
        }
      }
    }
    SystemNavigator.pop();
  }

  // Bloquea el autofoco de las pantallas del ERP ANTES de que abra el teclado.
  // Un campo solo recibe foco si el usuario lo tocó directamente o si está
  // navegando entre campos con el teclado (Tab/Enter).
  static final _bloqueoAutofoco = UserScript(
    source: """
      (function() {
        var lastTapTarget = null, lastTapTime = 0, lastKeyTime = 0;
        window.addEventListener('pointerdown', function(e) {
          lastTapTarget = e.target;
          lastTapTime = Date.now();
        }, true);
        window.addEventListener('keydown', function() {
          lastKeyTime = Date.now();
        }, true);

        function esCampo(el) {
          return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
        }
        function fuePorUsuario(el) {
          var porTeclado = Date.now() - lastKeyTime < 1000;
          var porToque = Date.now() - lastTapTime < 1000 && lastTapTarget &&
            (el === lastTapTarget || el.contains(lastTapTarget));
          return porTeclado || porToque;
        }

        // Intercepta el focus() programático (React, autofocus de SPA, etc.)
        var focusOriginal = HTMLElement.prototype.focus;
        HTMLElement.prototype.focus = function() {
          if (esCampo(this) && !fuePorUsuario(this)) return;
          return focusOriginal.apply(this, arguments);
        };

        // Red de seguridad para el atributo autofocus nativo del navegador:
        // quita el foco en el mismo instante, antes de que el teclado aparezca.
        document.addEventListener('focusin', function(e) {
          if (esCampo(e.target) && !fuePorUsuario(e.target)) e.target.blur();
        }, true);
      })();
    """,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // El botón atrás navega dentro del ERP; si no hay historial, cierra la app
        await _retroceder();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(erpUrl)),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  _bloqueoAutofoco,
                ]),
                initialSettings: InAppWebViewSettings(
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
