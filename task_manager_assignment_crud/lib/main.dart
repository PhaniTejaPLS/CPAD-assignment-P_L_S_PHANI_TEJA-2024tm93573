import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

void main()  async {

  WidgetsFlutterBinding.ensureInitialized();

  const keyApplicationId = 'oX8yRkufp4w0IGRlPsXIPT69eLIR0N6IYD7ILhwC';
  const keyClientKey = 'RMfauDFWuI0G9PXC4CpoOhsM38wmyZz6TbjoogGW';
  const keyParseServerUrl = "https://parseapi.back4app.com";

  await Parse().initialize(keyApplicationId, keyParseServerUrl, clientKey: keyClientKey, debug:true);


 //  var firstObject = ParseObject('FirstClass')
 //      ..set(
 //         'message', 'Hey, Parse is now connecterd!🙂');
 // await firstObject.save();

  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const TaskManagerScreen(),
    );
  }
}

class Task {
  Task({
    required this.objectId,
    required this.title,
    required this.dueDate,
    required this.isCompleted,
  });

  final String objectId;
  final String title;
  final DateTime dueDate;
  final bool isCompleted;

  Task copyWith({
    String? objectId,
    String? title,
    DateTime? dueDate,
    bool? isCompleted,
  }) {
    return Task(
      objectId: objectId ?? this.objectId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  static Task fromParseObject(ParseObject parseObject) {
    return Task(
      objectId: parseObject.objectId!,
      title: parseObject.get<String>('title') ?? '',
      dueDate: parseObject.get<DateTime>('dueDate') ?? DateTime.now(),
      isCompleted: parseObject.get<bool>('isCompleted') ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'dueDate': dueDate,
        'isCompleted': isCompleted,
      };
}

class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  late Future<List<Task>> _taskFuture;

  @override
  void initState() {
    super.initState();
    _taskFuture = _fetchTasks();
  }

  Future<List<Task>> _fetchTasks() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Task'))
      ..orderByAscending('dueDate');

    final response = await query.find();
    if(response.isEmpty) {
      return [];
    }

    return response.map((o) => Task.fromParseObject(o)).toList();
  }

  Future<Task> _createTask(String title, DateTime dueDate) async {
    final taskObject = ParseObject('Task')
      ..set('title', title)
      ..set('dueDate', dueDate)
      ..set('isCompleted', false);

    final response = await taskObject.save();
    if (!response.success || response.results == null || response.results!.isEmpty) {
      throw Exception(response.error?.message ?? 'Failed to create task');
    }

    return Task.fromParseObject(response.results!.first as ParseObject);
  }

  Future<Task> _updateTask(Task task) async {
    final taskObject = ParseObject('Task')
      ..objectId = task.objectId
      ..set('title', task.title)
      ..set('dueDate', task.dueDate)
      ..set('isCompleted', task.isCompleted);

    final response = await taskObject.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to update task');
    }

    return task;
  }

  Future<void> _deleteTask(Task task) async {
    final taskObject = ParseObject('Task')..objectId = task.objectId;

    final response = await taskObject.delete();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to delete task');
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _taskFuture = _fetchTasks();
    });
  }

  Future<void> _showAddTaskDialog() async {
    String? taskTitle;
    DateTime? dueDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: dueDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );

              if (selectedDate != null) {
                setLocalState(() => dueDate = selectedDate);
              }
            }

            return AlertDialog(
              title: const Text('Add Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Task name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => taskTitle = value.trim(),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      dueDate == null
                          ? 'Select due date'
                          : MaterialLocalizations.of(context)
                              .formatMediumDate(dueDate!),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if ((taskTitle ?? '').isEmpty || dueDate == null) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && taskTitle != null && dueDate != null) {
      try {
        final newTask = await _createTask(taskTitle!, dueDate!);
        setState(() {
          _taskFuture = _taskFuture.then((tasks) => [...tasks, newTask]);
        });
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating task: $error')),
        );
      }
    }
  }

  Future<void> _toggleTask(Task task, bool? value) async {
    final updatedTask = task.copyWith(isCompleted: value ?? false);

    try {
      await _updateTask(updatedTask);
      setState(() {
        _taskFuture = _taskFuture.then((tasks) {
          final index = tasks.indexWhere((t) => t.objectId == task.objectId);
          if (index == -1) return tasks;
          final updated = [...tasks];
          updated[index] = updatedTask;
          return updated;
        });
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: $error')),
      );
    }
  }

  Future<void> _deleteTaskWithConfirmation(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deleteTask(task);
        setState(() {
          _taskFuture = _taskFuture.then(
            (tasks) => tasks.where((t) => t.objectId != task.objectId).toList(),
          );
        });
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting task: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Task>>(
        future: _taskFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to load tasks.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _handleRefresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'No tasks yet.\nTap + to add your first task.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (value) => _toggleTask(task, value),
                    ),
                    title: Text(
                      task.title,
                      style: task.isCompleted
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    subtitle: Text(
                      'Due: ${MaterialLocalizations.of(context).formatMediumDate(task.dueDate)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteTaskWithConfirmation(task),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}