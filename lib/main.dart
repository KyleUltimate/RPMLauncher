// ignore_for_file: must_be_immutable

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:args/args.dart';
import 'package:contextmenu/contextmenu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:no_context_navigation/no_context_navigation.dart';
import 'package:rpmlauncher/Screen/Edit.dart';
import 'package:rpmlauncher/Screen/Log.dart';
import 'package:rpmlauncher/Utility/Analytics.dart';
import 'package:rpmlauncher/Utility/Updater.dart';
import 'package:rpmlauncher/Widget/CheckDialog.dart';
import 'package:dynamic_themes/dynamic_themes.dart';
import 'package:flutter/material.dart';
import 'package:io/io.dart';
import 'package:path/path.dart';
import 'package:rpmlauncher/Widget/OkClose.dart';
import 'package:split_view/split_view.dart';

import 'Launcher/GameRepository.dart';
import 'Launcher/InstanceRepository.dart';
import 'LauncherInfo.dart';
import 'Model/Instance.dart';
import 'Screen/About.dart';
import 'Screen/Account.dart';
import 'Screen/Settings.dart';
import 'Screen/VersionSelection.dart';
import 'Utility/Config.dart';
import 'Utility/Intents.dart';
import 'Utility/Loggger.dart';
import 'Utility/Theme.dart';
import 'Utility/i18n.dart';
import 'Utility/utility.dart';
import 'Widget/RWLLoading.dart';
import 'path.dart';

bool isInit = false;
late final Analytics ga;
final Logger logger = Logger.currentLogger;
List<String> LauncherArgs = [];
final Directory dataHome = path.currentDataHome;

final NavigatorState navigator = NavigationService.navigationKey.currentState!;

class RPMRouteSettings extends RouteSettings {
  String? routeName;
  final String? name;
  final Object? arguments;

  RPMRouteSettings({
    this.routeName,
    this.name,
    this.arguments,
  });
}

class PushTransitions<T> extends MaterialPageRoute<T> {
  PushTransitions({required WidgetBuilder builder, RouteSettings? settings})
      : super(builder: builder, settings: settings);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return new FadeTransition(opacity: animation, child: child);
  }
}

void main(List<String> _args) async {
  LauncherInfo.isDebugMode = kDebugMode;
  await path().init();
  LauncherArgs = _args;
  WidgetsFlutterBinding.ensureInitialized();
  await i18n.init();
  run().catchError((e) {
    logger.error(ErrorType.Unknown, e);
  });
}

class RPMNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    try {
      RPMRouteSettings _routeSettings = route.settings as RPMRouteSettings;
      ga.pageView(_routeSettings.routeName ?? "未知頁面", "Push");
    } catch (e) {}
  }
}

Future<void> run() async {
  runZonedGuarded(() async {
    logger.info("Starting");

    FlutterError.onError = (FlutterErrorDetails errorDetails) {
      logger.error(ErrorType.Flutter, errorDetails.exceptionAsString());

      // showDialog(
      //     context: navigator.context,
      //     builder: (context) => AlertDialog(
      //           title: Text("RPMLauncher 崩潰啦"),
      //           content: Text(errorDetails.toString()),
      //         ));
    };
    runApp(LauncherHome());
    ga = Analytics();
    await ga.ping();
  }, (error, stackTrace) {
    logger.error(ErrorType.Unknown, "$error\n$stackTrace");
  });
  logger.info("Start Done");
}

RouteSettings getInitRouteSettings() {
  String _route = '/';
  Map _arguments = {};
  ArgParser parser = ArgParser();
  parser.addOption('route', defaultsTo: '/', callback: (route) {
    _route = route!;
  });
  parser.addOption('arguments', defaultsTo: '{}', callback: (arguments) {
    _arguments = json.decode(arguments!);
  });

  parser.parse(LauncherArgs);
  return RouteSettings(name: _route, arguments: _arguments);
}

class LauncherHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeCollection = ThemeCollection(themes: {
      ThemeUtility.toInt(Themes.Light): ThemeData(
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.indigo),
          scaffoldBackgroundColor: Color.fromRGBO(225, 225, 225, 1.0),
          fontFamily: 'font',
          textTheme: new TextTheme(
            bodyText1: new TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                color: Color.fromRGBO(51, 51, 204, 1.0)),
          )),
      ThemeUtility.toInt(Themes.Dark): ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'font',
          textTheme: new TextTheme(
              bodyText1: new TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
          ))),
    });
    return Phoenix(
      child: DynamicTheme(
          themeCollection: themeCollection,
          defaultThemeId: ThemeUtility.toInt(Themes.Dark),
          builder: (context, theme) {
            return MaterialApp(
                debugShowCheckedModeBanner: false,
                navigatorKey: NavigationService.navigationKey,
                title: LauncherInfo.getUpperCaseName(),
                theme: theme,
                navigatorObservers: [RPMNavigatorObserver()],
                shortcuts: <LogicalKeySet, Intent>{
                  LogicalKeySet(LogicalKeyboardKey.escape): EscIntent(),
                  LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.shift,
                      LogicalKeyboardKey.keyR): HotReloadIntent(),
                  LogicalKeySet(
                          LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
                      RestartIntent(),
                },
                actions: <Type, Action<Intent>>{
                  EscIntent:
                      CallbackAction<EscIntent>(onInvoke: (EscIntent intent) {
                    if (navigator.canPop()) {
                      navigator.pop(true);
                    }
                  }),
                  HotReloadIntent: CallbackAction<HotReloadIntent>(
                      onInvoke: (HotReloadIntent intent) {
                    logger.send("Hot Reload");
                    Phoenix.rebirth(navigator.context);
                    showDialog(
                        context: navigator.context,
                        builder: (context) => AlertDialog(
                              title: Text(i18n.format('uttily.reload.hot')),
                              actions: [OkClose()],
                            ));
                  }),
                  RestartIntent: CallbackAction<RestartIntent>(
                      onInvoke: (RestartIntent intent) {
                    logger.send("Reload");
                    runApp(LauncherHome());
                    Future.delayed(Duration(seconds: 2), () {
                      showDialog(
                          context: navigator.context,
                          builder: (context) => AlertDialog(
                                title: Text(i18n.format('uttily.reload')),
                                actions: [OkClose()],
                              ));
                    });
                  }),
                },
                onGenerateInitialRoutes: (String initialRouteName) {
                  return [
                    navigator.widget.onGenerateRoute!(RouteSettings(
                        name: getInitRouteSettings().name,
                        arguments: getInitRouteSettings().arguments)) as Route,
                  ];
                },
                onGenerateRoute: (RouteSettings settings) {
                  RPMRouteSettings _settings = RPMRouteSettings(
                      name: settings.name, arguments: settings.arguments);
                  if (_settings.name == HomePage.route) {
                    _settings.routeName = "Home Page";
                    return PushTransitions(
                        settings: _settings,
                        builder: (context) => FutureBuilder(
                            future: Future.delayed(Duration(seconds: 2)),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                return HomePage();
                              } else {
                                return Material(
                                  child:
                                      RWLLoading(Animations: true, Logo: true),
                                );
                              }
                            }));
                  }

                  Uri uri = Uri.parse(_settings.name!);
                  if (_settings.name!.startsWith('/instance/') &&
                      uri.pathSegments.length > 2) {
                    // "/instance/${InstanceDirName}"
                    String InstanceDirName = uri.pathSegments[1];

                    if (_settings.name!
                        .startsWith('/instance/$InstanceDirName/edit')) {
                      _settings.routeName = "Edit Instance";
                      return PushTransitions(
                        settings: _settings,
                        builder: (context) => EditInstance(
                            InstanceDirName: InstanceDirName,
                            NewWindow:
                                (_settings.arguments as Map)['NewWindow']),
                      );
                    } else if (_settings.name!
                        .startsWith('/instance/$InstanceDirName/launcher')) {
                      _settings.routeName = "Launcher Instance";
                      return PushTransitions(
                        settings: _settings,
                        builder: (context) => LogScreen(InstanceDirName,
                            NewWindow:
                                (_settings.arguments as Map)['NewWindow']),
                      );
                    }
                  }

                  return PushTransitions(
                      settings: _settings, builder: (context) => HomePage());
                });
          }),
    );
  }
}

class HomePage extends StatefulWidget {
  static final String route = '/';
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Directory InstanceRootDir = GameRepository.getInstanceRootDir();

  Future<List<Instance>> getInstanceList() async {
    List<Instance> Instances = [];

    await InstanceRootDir.list().forEach((FSE) {
      if (FSE is Directory &&
          FSE
              .listSync()
              .any((file) => basename(file.path) == "instance.json")) {
        Instances.add(
            Instance(InstanceRepository.getInstanceDirNameByDir(FSE)));
      }
    });
    return Instances;
  }

  @override
  void initState() {
    InstanceRootDir.watch().listen((event) {
      try {
        setState(() {});
      } catch (e) {}
    });
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      run();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  late String name;
  bool start = true;
  int chooseIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (!isInit) {
      if (Config.getValue('init') == false) {
        Future.delayed(Duration.zero, () {
          showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  StatefulBuilder(builder: (context, setState) {
                    return AlertDialog(
                        title: Text(i18n.format('init.quick_setup.title'),
                            textAlign: TextAlign.center),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                "${i18n.format('init.quick_setup.content')}\n"),
                            SelectorLanguageWidget(setWidgetState: setState),
                          ],
                        ),
                        actions: [
                          OkClose(
                            onOk: () {
                              Config.change('init', true);
                            },
                          )
                        ]);
                  }));
        });
      } else {
        VersionTypes UpdateChannel =
            Updater.getVersionTypeFromString(Config.getValue('update_channel'));

        Updater.checkForUpdate(UpdateChannel).then((VersionInfo info) {
          if (info.needUpdate == true) {
            Future.delayed(Duration.zero, () {
              TextStyle _title = TextStyle(fontSize: 20);
              showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      StatefulBuilder(builder: (context, setState) {
                        return AlertDialog(
                            title: Text("更新 RPMLauncher",
                                textAlign: TextAlign.center),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              "偵測到您的 RPMLauncher 版本過舊，您是否需要更新，我們建議您更新以獲得更佳體驗\n",
                                          style: TextStyle(fontSize: 18),
                                        ),
                                        TextSpan(
                                          text:
                                              "最新版本: ${info.version}.${info.versionCode}\n",
                                          style: _title,
                                        ),
                                        TextSpan(
                                          text:
                                              "目前版本: ${LauncherInfo.getVersion()}.${LauncherInfo.getVersionCode()}\n",
                                          style: _title,
                                        ),
                                        TextSpan(
                                          text: "變更日誌: \n",
                                          style: _title,
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                    toolbarOptions: ToolbarOptions(
                                        copy: true,
                                        selectAll: true,
                                        cut: true)),
                                Container(
                                    width:
                                        MediaQuery.of(context).size.width / 2,
                                    height:
                                        MediaQuery.of(context).size.height / 3,
                                    child: Markdown(
                                      selectable: true,
                                      styleSheet: MarkdownStyleSheet(
                                          textAlign: WrapAlignment.center,
                                          textScaleFactor: 1.5,
                                          h1Align: WrapAlignment.center,
                                          unorderedListAlign:
                                              WrapAlignment.center),
                                      data: info.changelog.toString(),
                                      onTapLink: (text, url, title) {
                                        if (url != null) {
                                          utility.OpenUrl(url);
                                        }
                                      },
                                    ))
                              ],
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text("不要更新")),
                              TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    if (Platform.isMacOS) {
                                      showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                                title: Text(i18n
                                                    .format('gui.tips.info')),
                                                content: Text(
                                                    "RPMLauncher 目前不支援 MacOS 自動更新，抱歉造成困擾。"),
                                                actions: [OkClose()],
                                              ));
                                    } else {
                                      Updater.download(info);
                                    }
                                  },
                                  child: Text("更新"))
                            ]);
                      }));
            });
          }
        });
      }

      isInit = true;
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leadingWidth: 300,
        leading: Row(
          children: [
            IconButton(
                onPressed: () async {
                  await utility.OpenUrl(LauncherInfo.HomePageUrl);
                },
                icon: Image.asset("images/Logo.png", scale: 4),
                tooltip: i18n.format("homepage.website")),
            IconButton(
                icon: Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    PushTransitions(builder: (context) => SettingScreen()),
                  );
                },
                tooltip: i18n.format("gui.settings")),
            IconButton(
              icon: Icon(Icons.folder),
              onPressed: () {
                utility.OpenFileManager(path.currentDataHome);
              },
              tooltip: i18n.format("homepage.data.folder.open"),
            ),
            IconButton(
                icon: Icon(Icons.info),
                onPressed: () {
                  Navigator.push(
                    context,
                    PushTransitions(builder: (context) => AboutScreen()),
                  );
                },
                tooltip: i18n.format("homepage.about"))
          ],
        ),
        title: Text(
          LauncherInfo.getUpperCaseName(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.manage_accounts),
            onPressed: () {
              Navigator.push(
                context,
                PushTransitions(builder: (context) => AccountScreen()),
              );
            },
            tooltip: i18n.format("account.title"),
          ),
        ],
      ),
      body: FutureBuilder(
        builder: (context, AsyncSnapshot<List<Instance>> snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!.isNotEmpty) {
              return SplitView(
                  gripSize: 0,
                  controller: SplitViewController(weights: [0.7]),
                  children: [
                    Builder(
                      builder: (context) {
                        return GridView.builder(
                          itemCount: snapshot.data!.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 8),
                          physics: ScrollPhysics(),
                          itemBuilder: (context, index) {
                            String InstancePath = snapshot.data![index].path;
                            if (!snapshot.data![index].config.file
                                .existsSync()) {
                              return Container();
                            }

                            var photo;
                            if (File(join(InstancePath, "icon.png"))
                                .existsSync()) {
                              try {
                                photo = Image.file(File(join(
                                    snapshot.data![index].path, "icon.png")));
                              } catch (err) {
                                photo = Icon(
                                  Icons.image,
                                );
                              }
                            } else {
                              photo = Icon(
                                Icons.image,
                              );
                            }

                            return ContextMenuArea(
                              items: [
                                ListTile(
                                  title: Text('啟動'),
                                  subtitle: Text("啟動遊戲"),
                                  onTap: () {
                                    navigator.pop();
                                    snapshot.data![index].launcher();
                                  },
                                ),
                                ListTile(
                                  title: Text('編輯'),
                                  subtitle: Text("調整模組、地圖、世界、資源包、光影等設定"),
                                  onTap: () {
                                    navigator.pop();
                                    snapshot.data![index].edit();
                                  },
                                ),
                                ListTile(
                                  title: Text('複製'),
                                  subtitle: Text("複製此安裝檔"),
                                  onTap: () {
                                    navigator.pop();
                                    snapshot.data![index].copy();
                                  },
                                ),
                                ListTile(
                                  title: Text('刪除',
                                      style: TextStyle(color: Colors.red)),
                                  subtitle: Text("刪除此安裝檔"),
                                  onTap: () {
                                    navigator.pop();
                                    snapshot.data![index].delete();
                                  },
                                )
                              ],
                              child: Card(
                                child: InkWell(
                                  onTap: () {
                                    chooseIndex = index;
                                    setState(() {});
                                  },
                                  child: Column(
                                    children: [
                                      Expanded(child: photo),
                                      Text(snapshot.data![index].name,
                                          textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    Builder(builder: (context) {
                      if (chooseIndex == -1 ||
                          !InstanceRepository.InstanceConfigFile(
                                  snapshot.data![chooseIndex].path)
                              .existsSync() ||
                          (snapshot.data!.length - 1) < chooseIndex) {
                        return Container();
                      } else {
                        return Builder(
                          builder: (context) {
                            Widget photo;
                            String ChooseIndexPath =
                                snapshot.data![chooseIndex].path;

                            if (FileSystemEntity.typeSync(
                                    join(ChooseIndexPath, "icon.png")) !=
                                FileSystemEntityType.notFound) {
                              photo = Image.file(
                                  File(join(ChooseIndexPath, "icon.png")));
                            } else {
                              photo = const Icon(
                                Icons.image,
                                size: 100,
                              );
                            }

                            return Column(
                              children: [
                                Container(
                                  child: photo,
                                  width: 200,
                                  height: 160,
                                ),
                                Text(snapshot.data![chooseIndex].name,
                                    textAlign: TextAlign.center),
                                SizedBox(height: 12),
                                TextButton(
                                    onPressed: () {
                                      snapshot.data![chooseIndex].launcher();
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                            i18n.format("gui.instance.launch")),
                                      ],
                                    )),
                                SizedBox(height: 12),
                                TextButton(
                                    onPressed: () {
                                      snapshot.data![chooseIndex].edit();
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit,
                                        ),
                                        SizedBox(width: 5),
                                        Text(i18n.format("gui.edit")),
                                      ],
                                    )),
                                SizedBox(height: 12),
                                TextButton(
                                    onPressed: () {
                                      snapshot.data![chooseIndex].copy();
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.content_copy,
                                        ),
                                        SizedBox(width: 5),
                                        Text(i18n.format("gui.copy")),
                                      ],
                                    )),
                                SizedBox(height: 12),
                                TextButton(
                                    onPressed: () {
                                      snapshot.data![chooseIndex].delete();
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.delete,
                                        ),
                                        SizedBox(width: 5),
                                        Text(i18n.format("gui.delete")),
                                      ],
                                    )),
                              ],
                            );
                          },
                        );
                      }
                    }),
                  ],
                  viewMode: SplitViewMode.Horizontal);
            } else {
              return Transform.scale(
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                        Icon(
                          Icons.today,
                        ),
                        Text(i18n.format("homepage.instance.found")),
                        Text(i18n.format("homepage.instance.found.tips"))
                      ])),
                  scale: 2);
            }
          } else {
            return RWLLoading(
              Animations: false,
              Logo: true,
            );
          }
        },
        future: getInstanceList(),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          Navigator.push(
            context,
            PushTransitions(builder: (context) => new VersionSelection()),
          );
        },
        tooltip: i18n.format("version.list.instance.add"),
        child: Icon(Icons.add),
      ),
    );
  }
}
