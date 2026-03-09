import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/account.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/records/formatter/auto_decimal_shift_formatter.dart';
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
  DatabaseInterface database = ServiceConfig.database;
  final _formKey = GlobalKey<FormState>();

  String? _name;
  double _initialBalance = 0.0;
  late TextEditingController _balanceController;
  late String _decSep;
  late String _groupSep;
  late int _decDigits;
  Color? _selectedColor;
  int _selectedColorIndex = 0;
  Color? _pickedColor;
  int? _selectedIconCodePoint;

  EditAccountPageState(this.passedAccount);

  @override
  void initState() {
    super.initState();
    _decSep = getDecimalSeparator();
    _groupSep = getGroupingSeparator();
    _decDigits = getNumberDecimalDigits();
    if (passedAccount != null) {
      _name = passedAccount!.name;
      _initialBalance = passedAccount!.initialBalance;
      _balanceController = TextEditingController(
        text: _initialBalance.abs().toStringAsFixed(_decDigits).replaceAll('.', _decSep),
      );
      _selectedColor = passedAccount!.color;
      _selectedIconCodePoint = passedAccount!.iconCodePoint;
      // Try to match color to preset list
      _selectedColorIndex = Category.colors.indexOf(_selectedColor);
      if (_selectedColorIndex < 0) {
        _selectedColorIndex = -1;
        _pickedColor = _selectedColor;
      }
    } else {
      final zeroText = _decDigits <= 0
          ? '0'
          : '0$_decSep${List.filled(_decDigits, '0').join()}';
      _balanceController = TextEditingController(text: zeroText);
      _selectedColor = Category.colors[0];
      _selectedColorIndex = 0;
      _selectedIconCodePoint = Icons.account_balance_wallet.codePoint;
    }
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
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

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Container(
            padding: EdgeInsets.all(15),
            color: Theme.of(context).primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Choose a color".i18n,
                    style: TextStyle(color: Colors.white)),
                IconButton(
                  icon: Icon(Icons.close),
                  color: Colors.white,
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop('dialog'),
                ),
              ],
            ),
          ),
          titlePadding: EdgeInsets.all(0),
          contentPadding: EdgeInsets.all(0),
          content: SingleChildScrollView(
            child: MaterialPicker(
              pickerColor: _selectedColor ?? Category.colors[0]!,
              onColorChanged: (newColor) {
                setState(() {
                  _pickedColor = newColor;
                  _selectedColor = newColor;
                  _selectedColorIndex = -1;
                });
              },
              enableLabel: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorPickerCircle() {
    final isCustomSelected = _selectedColorIndex == -1;
    return GestureDetector(
      onTap: _openColorPicker,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _pickedColor == null
              ? LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.yellow, Colors.red, Colors.indigo, Colors.teal],
                )
              : LinearGradient(colors: [_pickedColor!, _pickedColor!]),
          border: Border.all(
            color: isCustomSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: Icon(Icons.colorize, color: Colors.white, size: 20),
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
                controller: _balanceController,
                decoration: InputDecoration(
                  labelText: "Initial balance".i18n,
                  border: InputBorder.none,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                style: TextStyle(fontSize: 20),
                keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [
                  AutoDecimalShiftFormatter(
                    decimalDigits: _decDigits,
                    decimalSep: _decSep,
                    groupSep: _groupSep,
                  ),
                ],
                onSaved: (v) {
                  final normalized = (v ?? '0').replaceAll(_decSep, '.');
                  _initialBalance = double.tryParse(normalized) ?? 0.0;
                },
                validator: (v) {
                  final normalized = (v ?? '').replaceAll(_decSep, '.');
                  return double.tryParse(normalized) == null ? "Invalid number".i18n : null;
                },
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
                    children: [
                      _buildColorPickerCircle(),
                      ...List.generate(Category.colors.length, (i) {
                        final c = Category.colors[i] ?? Colors.grey;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedColorIndex = i;
                            _selectedColor = c;
                            _pickedColor = null;
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
                    ],
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
