package com.example.refeicao_diaria

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "meu_almoco/sistema")
            .setMethodCallHandler { call, result ->
                val intent = when (call.method) {
                    "abrirConfiguracoesNotificacao" ->
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    "abrirConfiguracoesBateria" ->
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName"),
                        )
                    else -> null
                }
                if (intent == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                } catch (erro: Exception) {
                    result.error("indisponivel", erro.message, null)
                }
            }
    }
}