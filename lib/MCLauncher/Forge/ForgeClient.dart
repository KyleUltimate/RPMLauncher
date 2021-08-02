import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart';
import 'package:rpmlauncher/MCLauncher/Forge/ForgeAPI.dart';
import 'package:rpmlauncher/Utility/ModLoader.dart';
import 'package:rpmlauncher/Utility/utility.dart';

import '../../path.dart';
import '../APIs.dart';
import '../MinecraftClient.dart';

class ForgeClient implements MinecraftClient {
  Directory InstanceDir;

  String VersionMetaUrl;

  MinecraftClientHandler handler;

  var SetState;

  ForgeClient._init(
      {required this.InstanceDir,
      required this.VersionMetaUrl,
      required this.handler,
      required String VersionID,
      required SetState}) {}

  static Future<ForgeClient> createClient(
      {required Directory InstanceDir,
      required String VersionMetaUrl,
      required String VersionID,
      required setState}) async {
    await ForgeAPI().DownloadForgeInstaller(VersionID);

    var bodyString = await ForgeAPI().GetVersionJson(VersionID);
    Map<String, dynamic> body = await json.decode(bodyString);
    var ForgeMeta = body;
    return await new ForgeClient._init(
            handler: await new MinecraftClientHandler(),
            SetState: setState,
            InstanceDir: InstanceDir,
            VersionMetaUrl: VersionMetaUrl,
            VersionID: VersionID)
        ._Install(VersionMetaUrl, ForgeMeta, VersionID, InstanceDir, body["id"],
            setState);
  }

  Future<ForgeClient> DownloadForgeLibrary(Meta, VersionID, SetState_) async {
    Meta["libraries"].forEach((lib) async {
      if (lib["downloads"].keys.contains("artifact")) {
        var artifact = lib["downloads"]["artifact"];
        handler.DownloadTotalFileLength++;
        List split_ = artifact["path"].toString().split("/");

        if (lib["name"].toString().startsWith("net.minecraftforge:forge:")) {
          //處理一些例外錯誤
          var version =
              lib["name"].toString().split("net.minecraftforge:forge:").join();
          artifact["url"] =
              "${ForgeInstallerAPI}/${version}/forge-${version}-universal.jar";
        }

        handler.DownloadFile(
            artifact["url"],
            split_[split_.length - 1],
            join(dataHome.absolute.path, "versions", VersionID, "libraries",
                ModLoader().Forge),
            artifact["sha1"],
            SetState_);
      }
    });
    return this;
  }

  Future GetForgeArgs(Meta, VersionID) async {
    File ArgsFile =
        File(join(dataHome.absolute.path, "versions", VersionID, "args.json"));
    File NewArgsFile = File(join(dataHome.absolute.path, "versions", VersionID,
        "${ModLoader().Forge}_args.json"));
    Map ArgsObject = await json.decode(ArgsFile.readAsStringSync());
    ArgsObject["mainClass"] = Meta["mainClass"];
    for (var i in Meta["arguments"]["game"]) {
      ArgsObject["game"].add(i);
    }
    for (var i in Meta["arguments"]["jvm"]) {
      ArgsObject["jvm"].add(i);
    }
    NewArgsFile.writeAsStringSync(json.encode(ArgsObject));
  }

  Future InstallerJarHandler(VersionID, ForgeID) async {
    File InstallerFile = File(join(
        dataHome.absolute.path, "TempData", "forge-installer", "$ForgeID.jar"));
    final archive =
        await ZipDecoder().decodeBytes(InstallerFile.readAsBytesSync());
    for (final file in archive) {
      if (file.isFile &&
          file.toString().startsWith(utility
              .pathSeparator("maven/net/minecraftforge/forge/$ForgeID"))) {
        final data = file.content as List<int>;
        File JarFile = File(join(dataHome.absolute.path, "versions", VersionID,
            "libraries", ModLoader().Forge, file.name));
        JarFile.createSync(recursive: true);
        JarFile.writeAsBytesSync(data);
        break;
      }
    }
  }

  Future<ForgeClient> _Install(VersionMetaUrl, ForgeMeta, VersionID,
      InstanceDir, ForgeID, SetState) async {
    await handler.Install(VersionMetaUrl, VersionID, InstanceDir, SetState);
    await this.InstallerJarHandler(VersionID, ForgeID);
    await this.GetForgeArgs(ForgeMeta, VersionID);
    await this.DownloadForgeLibrary(ForgeMeta, VersionID, SetState);
    return this;
  }
}
