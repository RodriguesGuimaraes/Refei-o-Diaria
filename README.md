# Refeicao Diaria

Aplicativo Flutter para Android com cadastro e listagem local de refeicoes.
Cada registro possui data, descricao obrigatoria e foto opcional da galeria.
A listagem mostra primeiro as datas mais recentes; empates mostram o ultimo
registro cadastrado primeiro.

## Estrutura

```text
lib/
	models/refeicao.dart
	data/
		repositories/refeicao_repository.dart
		services/hive_service.dart
		services/notification_service.dart
	ui/
		views/home_page.dart
		viewmodels/home_viewmodel.dart
	main.dart
```

O modelo converte os dados para mapas. O HiveService abre a caixa `refeicoes`.
O repositorio salva os registros no Hive e copia fotos para o diretorio privado
do aplicativo, persistindo caminhos relativos. O HomeViewModel usa ChangeNotifier
e recebe dependencias injetadas; a tela nao acessa o Hive diretamente.

O seletor de galeria nao precisa de permissoes amplas de armazenamento.
Fotos recuperadas apos o Android encerrar a atividade ficam no rascunho de
uma nova refeicao, sem criar registros automaticamente. Cancelar o formulario
descarta o rascunho. Falhas ao salvar preservam os campos para nova tentativa.

## Executar no Android

Instale um Flutter compativel com a restricao Dart do pubspec e configure
o Android SDK, Java 17 e um aparelho ou emulador Android.

```sh
flutter pub get
flutter devices
flutter run -d <id-do-dispositivo>
```

## Verificacao

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Os testes usam Hive em diretorios temporarios e dependencias falsas para
selecionar fotos sem chamar plugins nativos nos testes de widget.
No aparelho, confira o cadastro com e sem foto, cancelamento da galeria,
reabertura do aplicativo, teclado e selecao de data.

## Limites desta etapa

NotificationService e apenas uma classe-base; notificacoes nao sao agendadas.
Camera, edicao, exclusao, sincronizacao e outras plataformas nao fazem parte
desta entrega. Os dados sobrevivem ao fechamento do app, mas limpar os dados
ou desinstalar pode remove-los. Nao ha criptografia adicional nem garantia de
transacao atomica entre o banco e os arquivos em caso de encerramento abrupto.
