import 'package:flutter/material.dart';
import 'package:piggybank/accounts/account-selector-page.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/date_picker_utils.dart';
import 'package:piggybank/models/account.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/i18n.dart';

class TransferPage extends StatefulWidget {
  TransferPage({Key? key}) : super(key: key);

  @override
  TransferPageState createState() => TransferPageState();
}

class TransferPageState extends State<TransferPage> {
  DatabaseInterface database = ServiceConfig.database;
  final _formKey = GlobalKey<FormState>();

  Account? _fromAccount;
  Account? _toAccount;
  double _amount = 0.0;
  DateTime _selectedDate = DateTime.now();
  String? _note;

  Future<void> _pickAccount(bool isFrom) async {
    final selected = await Navigator.push<Account>(
      context,
      MaterialPageRoute(builder: (_) => AccountSelectorPage()),
    );
    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromAccount = selected;
        } else {
          _toAccount = selected;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final firstDayOfWeek = getFirstDayOfWeekIndex();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (ctx, child) => DatePickerUtils.buildDatePickerWithFirstDayOfWeek(
          ctx, child, firstDayOfWeek),
    );
    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_fromAccount == null || _toAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select both accounts".i18n)),
      );
      return;
    }
    if (_fromAccount!.id == _toAccount!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("From and To accounts must be different".i18n)),
      );
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Amount must be greater than zero".i18n)),
      );
      return;
    }

    await database.addTransfer(
      _fromAccount!,
      _toAccount!,
      _amount,
      _selectedDate.toUtc(),
      timeZoneName: ServiceConfig.localTimezone,
      note: _note?.trim().isEmpty == true ? null : _note?.trim(),
    );
    Navigator.pop(context, true);
  }

  Widget _buildAccountRow(String label, Account? account, bool isFrom) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: () => _pickAccount(isFrom),
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    account?.color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                child: account?.iconCodePoint != null
                    ? Icon(
                        Account.iconFromCodePoint(account!.iconCodePoint!),
                        color: Colors.white,
                        size: 20,
                      )
                    : Icon(Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  SizedBox(height: 4),
                  Text(
                    account?.name ?? "Select Account".i18n,
                    style: TextStyle(
                      fontSize: 18,
                      color: account != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transfer between accounts".i18n),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildAccountRow("From".i18n, _fromAccount, true),
            SizedBox(height: 8),
            _buildAccountRow("To".i18n, _toAccount, false),
            SizedBox(height: 8),
            // Amount
            Card(
              elevation: 1,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: "Amount".i18n,
                    border: InputBorder.none,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  style: TextStyle(fontSize: 22),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onSaved: (v) => _amount = double.tryParse(v ?? '0') ?? 0.0,
                  validator: (v) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d <= 0) return "Invalid amount";
                    return null;
                  },
                ),
              ),
            ),
            SizedBox(height: 8),
            // Date
            Card(
              elevation: 1,
              child: InkWell(
                onTap: _pickDate,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(15, 15, 15, 15),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 28,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 20),
                      Text(
                        getDateStr(_selectedDate),
                        style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            // Note
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0, top: 10, right: 10, left: 10),
                child: TextFormField(
                  style: TextStyle(
                    fontSize: 22.0,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  onSaved: (v) => _note = v,
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: "Add a note".i18n,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(10),
                    label: Text("Note"),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        child: Icon(Icons.swap_horiz),
        tooltip: "Transfer".i18n,
      ),
    );
  }
}
