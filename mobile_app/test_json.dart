import 'dart:convert';
import 'package:mobile_app/models/match_model.dart';

void main() {
  final jsonString = '''[{"id":"192db1b2-b269-4518-b7d2-80e906d7366d","title":"FF","category":"BR","entry_fee":10.00,"total_spots":50,"prize_pool":100.00,"status":"upcoming","start_time":"2026-08-12T19:30:00+00:00","min_players":10,"result_submission_deadline":null,"filled_spots":0,"created_at":"2026-08-12T18:59:36.173121+00:00"}]''';
  
  final List<dynamic> jsonList = jsonDecode(jsonString);
  try {
    for (var item in jsonList) {
      final model = MatchModel.fromJson(item);
      print("Success: \${model.title}");
    }
  } catch (e, stack) {
    print("Error: \$e");
    print(stack);
  }
}
