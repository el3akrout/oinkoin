import 'package:flutter/material.dart';
import 'package:piggybank/accounts/edit-account-page.dart';
import 'package:piggybank/accounts/transfer-page.dart';
import 'package:piggybank/models/account.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/i18n.dart';

import '../helpers/records-utility-functions.dart';

class TabAccounts extends StatefulWidget {
  TabAccounts({Key? key}) : super(key: key);

  @override
  TabAccountsState createState() => TabAccountsState();
}

class TabAccountsState extends State<TabAccounts> {
  DatabaseInterface database = ServiceConfig.database;
  List<Account>? _accounts;
  double _totalBalance = 0.0;
  bool _balancesHidden = false;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> onTabChange() async {
    await _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    final accounts = await database.getAllAccounts();
    final total = await database.getTotalBalance();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _totalBalance = total;
      });
    }
  }

  Future<void> _openEditAccount({Account? account}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => EditAccountPage(passedAccount: account)),
    );
    if (result == true) {
      await _fetchAccounts();
    }
  }

  Future<void> _openTransfer() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TransferPage()),
    );
    if (result == true) {
      await _fetchAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Accounts".i18n),
        actions: [
          IconButton(
            icon: Icon(_balancesHidden ? Icons.visibility_off : Icons.visibility),
            tooltip: _balancesHidden ? "Show balances".i18n : "Hide balances".i18n,
            onPressed: () => setState(() => _balancesHidden = !_balancesHidden),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'transfer-fab',
            onPressed: _openTransfer,
            child: Icon(Icons.swap_horiz),
            tooltip: "Transfer between accounts".i18n,
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add-account-fab',
            onPressed: () => _openEditAccount(),
            child: Icon(Icons.add),
            tooltip: "Add new account".i18n,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_accounts == null) {
      return Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _buildTotalBalanceCard(),
        Expanded(child: _buildAccountList()),
      ],
    );
  }

  Widget _buildTotalBalanceCard() {
    return Card(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Total Balance".i18n,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text(
              _balancesHidden ? '••••••' : getCurrencyValueString(_totalBalance),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _totalBalance >= 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountList() {
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
      padding: EdgeInsets.only(bottom: 100),
      itemCount: _accounts!.length,
      itemBuilder: (context, i) {
        final account = _accounts![i];
        final balance = account.currentBalance ?? account.initialBalance;
        return Card(
          margin: EdgeInsets.fromLTRB(16, 4, 16, 4),
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: account.color ?? Colors.blueGrey,
              child: account.iconCodePoint != null
                  ? Icon(
                      Account.iconFromCodePoint(account.iconCodePoint!),
                      color: Colors.white,
                      size: 20,
                    )
                  : Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 20),
            ),
            title: Text(account.name ?? '',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            trailing: Text(
              _balancesHidden ? '••••' : getCurrencyValueString(balance),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: balance >= 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            onTap: () => _openEditAccount(account: account),
          ),
        );
      },
    );
  }
}
