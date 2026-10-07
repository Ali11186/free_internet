import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  Account? currentAccount;
  List<Account> accounts = [];
  bool darkMode = true;
  int balance = 0;

  bool collecting = false;
  List<Task> currentTasks = [];
  String currentTaskTitle = '';
  int currentTaskIndex = 0;
  int totalEarned = 0;

  Future<void> init() async {
    accounts = await StorageService.loadAccounts();
    darkMode = await StorageService.loadDarkMode();
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    darkMode = !darkMode;
    await StorageService.saveDarkMode(darkMode);
    notifyListeners();
  }

  Future<void> setAccount(Account acc) async {
    currentAccount = acc;
    await StorageService.addOrUpdateAccount(acc);
    accounts = await StorageService.loadAccounts();
    notifyListeners();
  }

  Future<void> refreshAccounts() async {
    accounts = await StorageService.loadAccounts();
    notifyListeners();
  }

  Future<void> logout() async {
    currentAccount = null;
    notifyListeners();
  }

  Future<int> loadBalance() async {
    if (currentAccount == null) return 0;
    balance = await ApiService.getBalance(currentAccount!.headers);
    notifyListeners();
    return balance;
  }

  Future<bool> validateSession(Account acc) async {
    return ApiService.isSessionValid(acc.headers);
  }

  Future<CollectResult> runCollect() async {
    if (currentAccount == null) {
      return CollectResult(coins: 0, error: true, tasks: []);
    }
    collecting = true;
    totalEarned = 0;
    notifyListeners();

    final before = await ApiService.getBalance(currentAccount!.headers);
    final tasks = await ApiService.getTasks(currentAccount!.headers);
    currentTasks = tasks;

    bool hadError = false;
    final results = <TaskResult>[];

    for (int i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      currentTaskIndex = i;
      currentTaskTitle = t.title;
      notifyListeners();

      final code = await ApiService.completeTask(currentAccount!.headers, t.id);
      if (code == 200) {
        t.rewarded = true;
        totalEarned += t.coins;
        results.add(TaskResult(task: t, status: TaskStatus.success));
      } else if (code == 400) {
        t.rewarded = true;
        results.add(TaskResult(task: t, status: TaskStatus.alreadyDone));
      } else if (code == 403) {
        hadError = true;
        results.add(TaskResult(task: t, status: TaskStatus.forbidden));
        break;
      } else {
        hadError = true;
        results.add(TaskResult(task: t, status: TaskStatus.failed));
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }

    final after = await ApiService.getBalance(currentAccount!.headers);
    balance = after;
    final actual = after - before;

    collecting = false;
    notifyListeners();
    return CollectResult(
      coins: actual > 0 ? actual : totalEarned,
      error: hadError,
      tasks: results,
    );
  }
}

enum TaskStatus { success, alreadyDone, forbidden, failed }

class TaskResult {
  final Task task;
  final TaskStatus status;
  TaskResult({required this.task, required this.status});
}

class CollectResult {
  final int coins;
  final bool error;
  final List<TaskResult> tasks;
  CollectResult({required this.coins, required this.error, required this.tasks});
}
