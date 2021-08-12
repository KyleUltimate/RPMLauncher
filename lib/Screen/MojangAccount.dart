import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:RPMLauncher/Account/Account.dart';
import 'package:RPMLauncher/Account/MojangAccountHandler.dart';
import 'package:RPMLauncher/Utility/i18n.dart';

import '../path.dart';
import 'Account.dart';

class MojangAccount_ extends State<MojangAccount> {
  late io.Directory AccountFolder;
  late io.File AccountFile;
  late Map _Account;

  @override
  void initState() {
    AccountFolder = configHome;
    AccountFile = io.File(join(AccountFolder.absolute.path, "accounts.json"));
    _Account = json.decode(AccountFile.readAsStringSync());
    if (_Account["mojang"] == null) {
      _Account["mojang"] = [];
    }

    super.initState();
    setState(() {});
  }

  var Password;

  var MojangAccountController = TextEditingController();
  var MojangPasswdController = TextEditingController();

  bool _obscureText = true;
  late String _password;

  void _toggle() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  var title_ = TextStyle(
    fontSize: 20.0,
  );

  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("登入 Mojang 帳號"),
        centerTitle: true,
        leading: new IconButton(
          icon: new Icon(Icons.arrow_back),
          tooltip: i18n.Format("gui.back"),
          onPressed: () {
            AccountFile.writeAsStringSync(json.encode(_Account));
            Navigator.push(
              context,
              new MaterialPageRoute(builder: (context) => AccountScreen()),
            );
          },
        ),
      ),
      body: Container(
          height: double.infinity,
          width: double.infinity,
          alignment: Alignment.center,
          child: ListView(
            children: [
              Center(
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                          labelText: 'Mojang 帳號',
                          hintText: '電子郵件',
                          prefixIcon: Icon(Icons.person)),
                      controller: MojangAccountController, // 設定控制器
                    ),
                    TextField(
                      decoration: InputDecoration(
                          labelText: 'Mojang 密碼',
                          hintText: '密碼',
                          prefixIcon: Icon(Icons.password)),
                      controller: MojangPasswdController,
                      onChanged: (val) => _password = val,
                      obscureText: _obscureText, // 設定控制器
                    ),
                    TextButton(
                        onPressed: _toggle,
                        child: Text(_obscureText ? "顯示密碼" : "隱藏密碼")),
                    IconButton(
                      icon: Icon(Icons.login),
                      onPressed: () {
                        if (MojangAccountController.text == "" ||
                            MojangPasswdController.text == "") {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text("帳號登入資訊"),
                                  content: Text("帳號或密碼不能是空的。"),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text(i18n.Format("gui.confirm")),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              });
                        } else {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text("帳號登入資訊"),
                                  content: FutureBuilder(
                                      future: MojangHandler.LogIn(
                                          MojangAccountController.text,
                                          MojangPasswdController.text),
                                      builder: (BuildContext context,
                                          AsyncSnapshot snapshot) {
                                        if (snapshot.hasError ||
                                            snapshot.data.runtimeType ==
                                                String) {
                                          if (snapshot.data ==
                                              "ForbiddenOperationException") {
                                            return Text("輸入的帳號或密碼錯誤");
                                          } else {
                                            return StatefulBuilder(builder:
                                                (BuildContext context,
                                                    StateSetter setState) {
                                              return Column(
                                                children: [
                                                  Text("發生未知錯誤"),
                                                  Text(snapshot.error
                                                      .toString()),
                                                ],
                                              );
                                            });
                                          }
                                        } else if (snapshot.hasData &&
                                            snapshot.data != null) {
                                          var data = snapshot.data;

                                          var UUID =
                                              data["selectedProfile"]["id"];
                                          var UserName =
                                              data["selectedProfile"]["name"];
                                          var Token = data["accessToken"];
                                          if (_Account["mojang"] == null) {
                                            _Account["mojang"] = {};
                                          }

                                          account.Add(
                                              "mojang",
                                              Token,
                                              UUID,
                                              UserName,
                                              data["user"]["username"]);

                                          if (account.GetIndex() == -1 ||
                                             account.GetType().isEmpty) {
                                            account.SetIndex(0);
                                            account.SetType(account.Mojang);
                                          }

                                          return Text("帳號新增成功\n\n玩家名稱: " +
                                              UserName +
                                              "\n玩家 UUID:" +
                                              UUID);
                                        } else {
                                          return SizedBox(
                                            child: Center(
                                              child: Column(
                                                children: <Widget>[
                                                  CircularProgressIndicator(),
                                                  SizedBox(height: 10),
                                                  Text("處理中，請稍後...")
                                                ],
                                              ),
                                            ),
                                            height: 80,
                                            width: 100,
                                          );
                                        }
                                      }),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text(i18n.Format("gui.confirm")),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          new MaterialPageRoute(
                                              builder: (context) =>
                                                  new AccountScreen()),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              });
                        }
                      },
                    ),
                    Text(i18n.Format("gui.login"))
                  ],
                ),
              )
            ],
          )),
    );
  }
}

class MojangAccount extends StatefulWidget {
  @override
  MojangAccount_ createState() => MojangAccount_();
}
