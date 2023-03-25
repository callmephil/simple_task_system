import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}
class TaskManager {
  // Singleton instance
  static final TaskManager _instance = TaskManager._privateConstructor();

  // Factory method to return the singleton instance
  factory TaskManager() {
    return _instance;
  }

  // Private constructor so that the class can't be instantiated externally
  TaskManager._privateConstructor() {
    // Subscribe to connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        print('lost internet pausing all tasks');
        // Pause all tasks
        pauseAllTasks();
      } else {
        // Resume all tasks
        resumeAllTasks();
      }
    });
  }

  // HashMap to hold the tasks that need to be processed
  final Map<String, Task> _tasks = {};

  int get taskCount => _tasks.length;

  // Method to add a task to the manager.
  void addTask(Task task) {
    _tasks[task.id] = task;
  }

  // Method to cancel all tasks in the manager.
  void cancelAllTasks() {
    _tasks.values.forEach((task) => task.cancel());
  }

  // Method to pause all tasks in the manager.
  void pauseAllTasks() {
    _tasks.values.forEach((task) => task.pause());
  }

  // Method to resume all tasks in the manager.
  void resumeAllTasks() {
    _tasks.values.forEach((task) => task.resume());
  }

  // Method to dispose and remove a task from the map
  void removeTask(String id) {
    final task = _tasks[id];

    if (task == null) {
      return;
    }

    task.dispose();
    _tasks.remove(id);
  }

  // Method to start all tasks in the manager.
  void startAllTasks() {
    if (_tasks.isEmpty) return;

    // Process each pending task in the map concurrently
    _tasks.values.where((e) => e.isPending).forEach((task) {
      Future.microtask(() {
        return task.perform();
      });
    });
  }
}

enum TaskStatus {
  pending,
  active,
  canceled,
  completed,
  paused,
  failed,
}

abstract class TaskState extends ChangeNotifier {
  // Internal
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  // Code
  late String id;
  TaskStatus _status = TaskStatus.pending;
  String taskValue = '';
  void setValue<T>(T value) {
    taskValue = value.toString();
    notifyListeners();
  }

  bool get isPending => _status == TaskStatus.pending;
  bool get isActive => _status == TaskStatus.active;
  bool get isCanceled => _status == TaskStatus.canceled;
  bool get isCompleted => _status == TaskStatus.completed;
  bool get isPaused => _status == TaskStatus.paused;
  bool get isFailed => _status == TaskStatus.failed;

  // getter to check the status of a task
  String get status => _status.name;

  void setStatus(TaskStatus status) {
    _status = status;
    notifyListeners();
  }
}

class Task extends TaskState {
  final void Function()? onComplete;

  Task({
    this.onComplete,
  }) {
    // set a single unique id to the task.
    id = UniqueKey().toString();
  }

  // Perform some dummy async operation.
  Future<void> perform() async {
    if (!isPending) return;

    setStatus(TaskStatus.active);
    for (int i = 1000; i > 0; i--) {
      while (isPaused || isCanceled) {
        await Future.delayed(const Duration(seconds: 1));
      }
      setValue(i);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 250));
    }
    setStatus(TaskStatus.completed);
    onComplete?.call();
  }

  // Method to pause a task if it's active.
  void pause() {
    if (!isActive) return;

    setStatus(TaskStatus.paused);
  }

  // Method to resume a task if it's paused
  void resume() {
    if (!isPaused) return;

    setStatus(TaskStatus.active);
  }

  // Method to cancel a task if it's active or paused
  void cancel() {
    if (!isActive && !isPaused) return;

    setStatus(TaskStatus.canceled);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TaskManager _taskManager = TaskManager();
  final List<int> completedTask = [];

  @override
  void initState() {
    super.initState();
  }

  void _addTask() {
    Task newTask = Task(
      onComplete: () => setState(() => completedTask.add(1)),
    );

    _taskManager.addTask(newTask);
    newTask.addListener(() {
      if (!mounted) {
        return;
      }

      print('listener update');
      setState(() {});
    });

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            Text('Count of task in manager: ${_taskManager.taskCount}'),
            Text('Completed Tasks count: ${completedTask.length}'),
            TextButton(
              onPressed: () => _taskManager.startAllTasks(),
              child: const Text('Process All Tasks:'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _taskManager.taskCount,
                itemBuilder: (context, index) {
                  final e = _taskManager._tasks[index];
                  return Row(
                    children: [
                      TextButton(
                        onPressed: e.perform,
                        child: const Text('start'),
                      ),
                      TextButton(
                        onPressed: e.pause,
                        child: const Text('pause'),
                      ),
                      TextButton(
                        onPressed: e.resume,
                        child: const Text('resume'),
                      ),
                      TextButton(
                        onPressed: e.cancel,
                        child: const Text('cancel'),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _taskManager.removeTask(e.id);
                            });
                          },
                          child: Text('${e.status} | ${e.taskValue}'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        tooltip: 'add task',
        child: const Icon(Icons.add),
      ),
    );
  }
}
