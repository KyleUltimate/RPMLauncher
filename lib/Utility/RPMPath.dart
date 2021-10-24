import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rpmlauncher/Launcher/GameRepository.dart';
import 'package:rpmlauncher/Utility/Config.dart';
import 'package:rpmlauncher/Utility/Extensions.dart';
import 'package:rpmlauncher/Utility/Utility.dart';
import 'package:rpmlauncher/main.dart';

late Directory _root;

class RPMPath {
  static Directory get defaultDataHome => _root;
  static Directory get currentConfigHome => defaultDataHome;
  static Directory get currentDataHome {
    try {
      return Directory(Config.getValue('data_home'));
    } catch (e) {
      init();
      return Directory.current;
    }
  }

  static Future<void> init() async {
    late String _base;
    try {
      _base = (await getApplicationDocumentsDirectory()).absolute.path;

      if (Platform.isLinux) {
        _base = absolute(Platform.environment['HOME']!);
      }
      if (!_base.isASCII) {
        /// 非 英文/數字 符號
        _base = Directory.systemTemp.absolute.path;
      }
    } catch (e) {
      _base = Directory.current.absolute.path;
    }
    _root = Directory(join(_base, "RPMLauncher", "data"));

    Uttily.createFolderOptimization(_root);
    GameRepository.init(_root);
    Uttily.createFolderOptimization(currentDataHome);
  }
}
