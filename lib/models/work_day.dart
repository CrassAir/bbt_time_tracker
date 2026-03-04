import 'package:objectbox/objectbox.dart';

@Entity()
class WorkDay {
  @Id()
  int id = 0;

  // === ВРЕМЯ ИЗ ЗАДАЧ ===
  int totalEstimateMilliseconds = 0;      // Сумма estimate ВСЕХ задач дня
  int totalSpentMilliseconds = 0;         // Сумма spent ВСЕХ задач дня
  int carriedOverMilliseconds = 0;        // Перенос на следующий день (spent - estimate)

  // === БАЛАНС ===
  int prevWorkTimeMilliseconds = 0;       // Получено с предыдущего дня
  int debtOfTimeMilliseconds = 0;         // Задолженность (если spent > estimate)
  int freeTimeMilliseconds = 0;           // Свободное время (если spent < estimate)

  @Property(type: PropertyType.date)
  DateTime createToDate = DateTime.now().add(const Duration(days: 1));

  @Property(type: PropertyType.date)
  DateTime? startWorkDateTime;

  @Property(type: PropertyType.date)
  DateTime? endWorkDateTime;

  // === Геттеры/сеттеры для времени из задач ===
  Duration get totalEstimate => Duration(milliseconds: totalEstimateMilliseconds);
  set totalEstimate(Duration value) => totalEstimateMilliseconds = value.inMilliseconds;

  Duration get totalSpent => Duration(milliseconds: totalSpentMilliseconds);
  set totalSpent(Duration value) => totalSpentMilliseconds = value.inMilliseconds;

  Duration get carriedOver => Duration(milliseconds: carriedOverMilliseconds);
  set carriedOver(Duration value) => carriedOverMilliseconds = value.inMilliseconds;

  // === Геттеры/сеттеры для баланса ===
  Duration get prevWorkTime => Duration(milliseconds: prevWorkTimeMilliseconds);
  set prevWorkTime(Duration value) => prevWorkTimeMilliseconds = value.inMilliseconds;

  Duration get debtOfTime => Duration(milliseconds: debtOfTimeMilliseconds);
  set debtOfTime(Duration value) => debtOfTimeMilliseconds = value.inMilliseconds;

  Duration get freeTime => Duration(milliseconds: freeTimeMilliseconds);
  set freeTime(Duration value) => freeTimeMilliseconds = value.inMilliseconds;

  // === ВЫЧИСЛЯЕМЫЕ ПОЛЯ ===

  /// Баланс дня: (totalSpent + prevWorkTime) - totalEstimate
  /// 
  /// Если > 0: задолженность (перерасход)
  /// Если < 0: свободное время (экономия)
  /// Если = 0: баланс
  Duration get balance {
    final totalAvailable = totalEstimate + prevWorkTime;
    final difference = totalSpent - totalAvailable;
    return difference;
  }

  /// Задолженность в миллисекундах (положительное значение)
  int get debtMilliseconds {
    final balance = this.balance.inMilliseconds;
    return balance > 0 ? balance : 0;
  }

  /// Свободное время в миллисекундах (положительное значение)
  int get freeMilliseconds {
    final balance = this.balance.inMilliseconds;
    return balance < 0 ? -balance : 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkDay && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
