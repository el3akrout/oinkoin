import 'package:flutter/material.dart';
import 'package:piggybank/models/account.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/i18n.dart';

import '../helpers/records-utility-functions.dart';

class AccountSelectorPage extends StatefulWidget {
  AccountSelectorPage({Key? key}) : super(key: key);

  @override
  AccountSelectorPageState createState() => AccountSelectorPageState();
}

class AccountSelectorPageState extends State<AccountSelectorPage> {
  DatabaseInterface database = ServiceConfig.database;
  List<Account>? _accounts;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    final accounts = await database.getAllAccounts();
    setState(() {
      _accounts = accounts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Select Account".i18n),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_accounts == null) {
      return Center(child: CircularProgressIndicator());
    }
    if (_accounts!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No accounts yet.".i18n,
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _accounts!.length,
      itemBuilder: (context, i) {
        final account = _accounts![i];
        final balance = account.currentBalance ?? account.initialBalance;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: account.color ?? Colors.blueGrey,
            child: account.iconCodePoint != null
                ? Icon(
                    IconData(account.iconCodePoint!,
                        fontFamily: 'MaterialIcons'),
                    color: Colors.white,
                    size: 20,
                  )
                : Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 20),
          ),
          title: Text(account.name ?? ''),
          subtitle: Text(getCurrencyValueString(balance)),
          onTap: () => Navigator.pop(context, account),
        );
      },
    );
  }
}
