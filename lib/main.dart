import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'models/event.dart';

// 全局通知插件实例
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  // 初始化Flutter绑定
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Hive本地数据库
  await Hive.initFlutter();
  Hive.registerAdapter(EventAdapter()); // 注册实体适配器
  await Hive.openBox<Event>('events'); // 打开日程数据库表
  
  // 初始化本地通知
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // 安卓通知图标
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 启动应用
  runApp(const MyApp());
}

// 应用根组件
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '鸿蒙日历App',
      theme: ThemeData(primarySwatch: Colors.blue), // 主题色
      home: const CalendarPage(),
      debugShowCheckedModeBanner: false, // 隐藏调试横幅
    );
  }
}

// 日历主页面
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month; // 默认月视图
  DateTime _focusedDay = DateTime.now(); // 当前聚焦日期
  DateTime? _selectedDay; // 用户选中的日期
  final Box<Event> _eventBox = Hive.box<Event>('events'); // 日程数据库实例

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('鸿蒙日历App')),
      body: Column(
        children: [
          // 日历视图组件
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1), // 日历起始日期
            lastDay: DateTime.utc(2030, 12, 31), // 日历结束日期
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            // 选中日期回调
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            // 切换视图（月/周/日）回调
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            // 加载指定日期的日程
            eventLoader: (day) => _getEventsForDay(day),
            locale: 'zh_CN', // 中文显示
          ),
          // 日程列表
          Expanded(
            child: _selectedDay != null
                ? _buildEventList(_selectedDay!)
                : const Center(child: Text('请选择日期查看/添加日程')),
          ),
        ],
      ),
      // 添加日程按钮
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddEventDialog(),
      ),
    );
  }

  // 获取指定日期的所有日程
  List<Event> _getEventsForDay(DateTime day) {
    return _eventBox.values
        .where((event) => isSameDay(event.date, day))
        .toList();
  }

  // 构建日程列表
  Widget _buildEventList(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) {
      return const Center(child: Text('当前日期暂无日程'));
    }
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          title: Text(event.title),
          subtitle: Text(
            '${event.description}\n时间：${event.time.format(context)}${event.isRemind ? '（已开启提醒）' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 编辑按钮
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showAddEventDialog(event),
              ),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteEvent(event),
              ),
            ],
          ),
        );
      },
    );
  }

  // 添加/编辑日程弹窗
  void _showAddEventDialog([Event? event]) async {
    final isEdit = event != null;
    final TextEditingController titleController =
        TextEditingController(text: event?.title ?? '');
    final TextEditingController descController =
        TextEditingController(text: event?.description ?? '');
    TimeOfDay selectedTime = event?.time ?? TimeOfDay.now();
    DateTime selectedDate = event?.date ?? _selectedDay ?? DateTime.now();
    bool isRemind = event?.isRemind ?? false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '编辑日程' : '添加日程'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 日程标题输入框
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '日程标题',
                  hintText: '请输入日程名称',
                ),
                maxLength: 20,
              ),
              // 日程描述输入框
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '日程描述',
                  hintText: '请输入日程详情（选填）',
                ),
                maxLines: 3,
              ),
              // 时间选择
              ListTile(
                title: const Text('选择时间'),
                trailing: Text(selectedTime.format(context)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) setState(() => selectedTime = time);
                },
              ),
              // 提醒开关
              SwitchListTile(
                title: const Text('开启日程提醒'),
                value: isRemind,
                onChanged: (val) => setState(() => isRemind = val),
              ),
            ],
          ),
        ),
        actions: [
          // 取消按钮
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          // 保存按钮
          TextButton(
            child: const Text('保存'),
            onPressed: () {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入日程标题')),
                );
                return;
              }
              // 构建新日程对象
              final newEvent = Event(
                id: event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                description: descController.text.trim(),
                date: selectedDate,
                time: selectedTime,
                isRemind: isRemind,
              );
              // 保存到数据库
              if (isEdit) {
                _eventBox.put(event!.id, newEvent);
              } else {
                _eventBox.add(newEvent);
              }
              // 开启提醒则设置定时通知
              if (isRemind) {
                _scheduleNotification(newEvent);
              }
              Navigator.pop(context);
              setState(() {}); // 刷新页面
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isEdit ? '日程编辑成功' : '日程添加成功')),
              );
            },
          ),
        ],
      ),
    );
  }

  // 删除日程
  void _deleteEvent(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('是否删除「${event.title}」这个日程？'),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('删除', style: TextStyle(color: Colors.red)),
            onPressed: () {
              _eventBox.delete(event.id); // 从数据库删除
              // 取消该日程的提醒（如果有）
              if (event.isRemind) {
                flutterLocalNotificationsPlugin.cancel(int.parse(event.id));
              }
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('日程已删除')),
              );
            },
          ),
        ],
      ),
    );
  }

  // 配置日程提醒（本地通知）
  Future<void> _scheduleNotification(Event event) async {
    // 拼接提醒时间
    final scheduledTime = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      event.time.hour,
      event.time.minute,
    );
    // 若提醒时间已过，不设置
    if (scheduledTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提醒时间已过，无法设置提醒')),
      );
      return;
    }
    // 安卓通知配置
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'calendar_reminder', // 通知渠道ID
      '日程提醒', // 通知渠道名称
      channelDescription: '日历App的日程提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);
    // 调度定时通知
    await flutterLocalNotificationsPlugin.schedule(
      int.parse(event.id), // 通知ID（与日程ID一致）
      event.title, // 通知标题
      event.description.isNotEmpty ? event.description : '您有一个日程待处理', // 通知内容
      scheduledTime, // 提醒时间
      notificationDetails,
    );
  }
}