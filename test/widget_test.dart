import 'package:flutter_test/flutter_test.dart';
import 'package:bm_work_tracker/models.dart';

void main() {
  test('duration formatting', () {
    expect(fmtMins(90), '1h 30m');
    expect(fmtMins(45), '45m');
    expect(fmtMins(120), '2h');
  });
}
