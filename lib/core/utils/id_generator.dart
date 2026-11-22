/// Generates collision-free local IDs even for rapid back-to-back inserts.
class IdGenerator {
  IdGenerator._();

  static int _counter = 0;

  static String next(String prefix) {
    _counter++;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }
}
