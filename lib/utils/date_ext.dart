extension DateTimeEndOfDay on DateTime? {
  DateTime? get endOfDay {
    if (this == null) return null;
    return DateTime(this!.year, this!.month, this!.day, 23, 59, 59);
  }

  DateTime? get startOfDay {
    if (this == null) return null;
    return DateTime(this!.year, this!.month, this!.day, 0, 0, 0);
  }
}
