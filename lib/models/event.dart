import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'generated/event.g.dart'; // 自动生成的适配器文件

// Hive实体类，typeId需唯一（0-223）
@HiveType(typeId: 0)
class Event {
  @HiveField(0)
  final String id;              // 日程唯一标识

  @HiveField(1)
  final String title;           // 日程标题

  @HiveField(2)
  final String description;    // 日程描述

  @HiveField(3)
  final DateTime date;          // 日程日期

  @HiveField(4)
  final TimeOfDay time;         // 日程时间

  @HiveField(5)
  final bool isRemind;          // 是否开启提醒

  // 构造函数
  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.isRemind,
  });
}