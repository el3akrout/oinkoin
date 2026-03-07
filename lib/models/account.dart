import 'package:flutter/material.dart';
import 'package:piggybank/models/model.dart';

import '../helpers/color-utils.dart';

class Account extends Model {
  int? id;
  String? name;
  Color? color;
  int? iconCodePoint;
  double initialBalance;
  double? currentBalance; // computed — NOT in toMap

  Account(
    this.name, {
    this.id,
    this.color,
    this.iconCodePoint,
    this.initialBalance = 0.0,
    this.currentBalance,
  });

  @override
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'name': name,
      'initial_balance': initialBalance,
      'color': color != null ? serializeColorToString(color!) : null,
      'icon': iconCodePoint,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  static Account fromMap(Map<String, dynamic> map) {
    String? serializedColor = map['color'] as String?;
    Color? color;
    if (serializedColor != null) {
      List<int> colorComponents =
          serializedColor.split(':').map(int.parse).toList();
      color = Color.fromARGB(colorComponents[0], colorComponents[1],
          colorComponents[2], colorComponents[3]);
    }

    double? currentBalance;
    if (map.containsKey('current_balance') && map['current_balance'] != null) {
      currentBalance = (map['current_balance'] as num).toDouble();
    }

    return Account(
      map['name'] as String?,
      id: map['id'] as int?,
      color: color,
      iconCodePoint: map['icon'] as int?,
      initialBalance: map['initial_balance'] != null
          ? (map['initial_balance'] as num).toDouble()
          : 0.0,
      currentBalance: currentBalance,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Account && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
