import 'package:flutter/material.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/models/account.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/i18n.dart';

class EditAccountPage extends StatefulWidget {
  final Account? passedAccount;

  EditAccountPage({Key? key, this.passedAccount}) : super(key: key);

  @override
  EditAccountPageState createState() =>
      EditAccountPageState(passedAccount);
}

class EditAccountPageState extends State<EditAccountPage> {
  Account? passedAccount;
  Account? account;
  DatabaseInterface database = ServiceConfig.database;
  final _formKey = GlobalKey<FormState>();

  String? _name;
  double _initialBalance = 0.0;
  Color? _selectedColor;
  int _selectedColorIndex = 0;
  int? _selectedIconCodePoint;

  EditAccountPageState(this.passedAccount);

  @override
  void initState() {
    super.initState();
    if (passedAccount != null) {
      _name = passedAccount!.name;
      _initialBalance = passedAccount!.initialBalance;
      _selectedColor = passedAccount!.color;
      _selectedIconCodePoint = passedAccount!.iconCodePoint;
      // Try to match color to preset list
      _selectedColorIndex = Category.colors.indexOf(_selectedColor);
      if (_selectedColorIndex < 0) _selectedColorIndex = 0;
    } else {
      _selectedColor = Category.colors[0];
      _selectedColorIndex = 0;
      _selectedIconCodePoint = Icons.account_balance_wallet.codePoint;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final acc = Account(
      _name,
      color: _selectedColor,
      iconCodePoint: _selectedIconCodePoint,
      initialBalance: _initialBalance,
    );

    if (passedAccount == null) {
      await database.addAccount(acc);
    } else {
      await database.updateAccount(passedAccount!.id!, acc);
    }
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialogBuilder("Critical action".i18n)
          .addSubtitle(
              "Delete this account?".i18n + "\n" +
              "Deleting this account will not remove its associated records.".i18n)
          .addTrueButtonName("Yes".i18n)
          .addFalseButtonName("No".i18n)
          .build(ctx),
    );
    if (confirmed == true) {
      await database.deleteAccount(passedAccount!.id!);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = passedAccount != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Account".i18n : "New Account".i18n),
        actions: isEditing
            ? [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') _delete();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text("Delete this account?".i18n),
                    ),
                  ],
                )
              ]
            : null,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        child: Icon(Icons.save),
        tooltip: 'Save'.i18n,
      ),
    );
  }

  Widget _buildBody() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Name
          Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: TextFormField(
                initialValue: _name,
                decoration: InputDecoration(
                  labelText: "Account".i18n,
                  border: InputBorder.none,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                style: TextStyle(fontSize: 20),
                onSaved: (v) => _name = v?.trim(),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Account".i18n
                    : null,
              ),
            ),
          ),
          SizedBox(height: 8),
          // Initial balance
          Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: TextFormField(
                initialValue: _initialBalance.toString(),
                decoration: InputDecoration(
                  labelText: "Initial balance".i18n,
                  border: InputBorder.none,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                style: TextStyle(fontSize: 20),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onSaved: (v) =>
                    _initialBalance = double.tryParse(v ?? '0') ?? 0.0,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? "Invalid number" : null,
              ),
            ),
          ),
          SizedBox(height: 8),
          // Color picker
          Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Choose a color".i18n,
                      style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(Category.colors.length, (i) {
                      final c = Category.colors[i] ?? Colors.grey;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedColorIndex = i;
                          _selectedColor = c;
                        }),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColorIndex == i
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          // Icon picker
          Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Icon".i18n,
                      style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Account.icons.map((icon) {
                      final isSelected =
                          _selectedIconCodePoint == icon.codePoint;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedIconCodePoint = icon.codePoint;
                        }),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (_selectedColor ?? Colors.blueGrey)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(icon,
                              color: isSelected ? Colors.white : null,
                              size: 22),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
