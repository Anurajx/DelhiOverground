import 'package:flutter_test/flutter_test.dart';
import 'package:string_similarity/string_similarity.dart';

class TestSearchItem {
  final Map<String, dynamic> station;
  final String name;
  final String hindi;
  final List<String> nameWords;
  final List<String> hindiWords;

  TestSearchItem({
    required this.station,
    required this.name,
    required this.hindi,
    required this.nameWords,
    required this.hindiWords,
  });
}

double calculateScore(TestSearchItem item, String cleanQuery) {
  double score = 0.0;
  bool matched = false;

  final name = item.name;
  final hindi = item.hindi;

  // 1. Exact Match
  if (name == cleanQuery || hindi == cleanQuery) {
    score += 10000.0;
    matched = true;
  }

  // 2. Prefix Match of Full Name
  if (name.startsWith(cleanQuery) || hindi.startsWith(cleanQuery)) {
    score += 5000.0 + (100.0 * cleanQuery.length / (name.isNotEmpty ? name.length : 1));
    matched = true;
  }

  // 3. Prefix Match of Individual Words
  int wordIndex = 0;
  for (final word in item.nameWords) {
    if (word.startsWith(cleanQuery)) {
      final wordBonus = wordIndex == 0 ? 3500.0 : 3000.0 - (wordIndex * 100.0);
      score = score > wordBonus ? score : wordBonus + (100.0 * cleanQuery.length / word.length);
      matched = true;
    }
    wordIndex++;
  }

  wordIndex = 0;
  for (final word in item.hindiWords) {
    if (word.startsWith(cleanQuery)) {
      final wordBonus = wordIndex == 0 ? 3500.0 : 3000.0 - (wordIndex * 100.0);
      score = score > wordBonus ? score : wordBonus + (100.0 * cleanQuery.length / word.length);
      matched = true;
    }
    wordIndex++;
  }

  // 4. Substring Match
  if (name.contains(cleanQuery) || hindi.contains(cleanQuery)) {
    final substringScore = 1000.0 + (100.0 * cleanQuery.length / (name.isNotEmpty ? name.length : 1));
    score = score > substringScore ? score : substringScore;
    matched = true;
  }

  // 5. Fuzzy Match (Dice's coefficient) - only run for query length >= 3
  if (cleanQuery.length >= 3) {
    double maxSimilarity = 0.0;
    bool fuzzyMatched = false;

    // Full-name similarity
    final nameSimilarity = StringSimilarity.compareTwoStrings(name, cleanQuery);
    final hindiSimilarity = StringSimilarity.compareTwoStrings(hindi, cleanQuery);
    final maxFullNameSim = nameSimilarity > hindiSimilarity ? nameSimilarity : hindiSimilarity;
    if (maxFullNameSim > 0.35) {
      maxSimilarity = maxFullNameSim;
      fuzzyMatched = true;
    }

    // Word-level similarity
    for (final word in item.nameWords) {
      if (word.length >= 3) {
        final sim = StringSimilarity.compareTwoStrings(word, cleanQuery);
        if (sim > 0.5 && sim > maxSimilarity) {
          maxSimilarity = sim;
          fuzzyMatched = true;
        }
      }
    }
    for (final word in item.hindiWords) {
      if (word.length >= 3) {
        final sim = StringSimilarity.compareTwoStrings(word, cleanQuery);
        if (sim > 0.5 && sim > maxSimilarity) {
          maxSimilarity = sim;
          fuzzyMatched = true;
        }
      }
    }

    if (fuzzyMatched) {
      final fuzzyScore = maxSimilarity * 400.0;
      score = score > fuzzyScore ? score : fuzzyScore;
      matched = true;
    }
  }

  return matched ? score : -1.0;
}

void main() {
  group('Station Search Ranking Tests', () {
    final rawStations = [
      {"Name": "Safiyabad Crossing", "Hindi": "Safiyabad Crossing"},
      {"Name": "Narela Terminal", "Hindi": "Narela Terminal"},
      {"Name": "Police Station Narela", "Hindi": "Police Station Narela"},
      {"Name": "Narela A-6 / CPJ College", "Hindi": "Narela A-6 / CPJ College"},
    ];

    late List<TestSearchItem> searchItems;

    setUp(() {
      searchItems = rawStations.map((stationMap) {
        final name = stationMap["Name"]!.toLowerCase();
        final hindi = stationMap["Hindi"]!.toLowerCase();
        final nameWords = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final hindiWords = hindi.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        return TestSearchItem(
          station: stationMap,
          name: name,
          hindi: hindi,
          nameWords: nameWords,
          hindiWords: hindiWords,
        );
      }).toList();
    });

    test('Query "narela" prioritizes "Narela Terminal" over "Police Station Narela"', () {
      const query = "narela";
      
      final results = searchItems
          .map((item) => MapEntry(item, calculateScore(item, query)))
          .where((entry) => entry.value >= 0)
          .toList();

      results.sort((a, b) => b.value.compareTo(a.value));

      expect(results.length, equals(3)); // Narela Terminal, Police Station Narela, Narela A-6 / CPJ College
      expect(results[0].key.station["Name"], equals("Narela Terminal"));
      expect(results[1].key.station["Name"], equals("Narela A-6 / CPJ College")); // "Narela" is first word, shorter overall name
      expect(results[2].key.station["Name"], equals("Police Station Narela")); // "Narela" is 3rd word
    });

    test('Query "safiyabad" matches "Safiyabad Crossing" first', () {
      const query = "safiyabad";

      final results = searchItems
          .map((item) => MapEntry(item, calculateScore(item, query)))
          .where((entry) => entry.value >= 0)
          .toList();

      results.sort((a, b) => b.value.compareTo(a.value));

      expect(results.length, equals(1));
      expect(results[0].key.station["Name"], equals("Safiyabad Crossing"));
    });

    test('Query "narela terminal" performs exact match first', () {
      const query = "narela terminal";

      final results = searchItems
          .map((item) => MapEntry(item, calculateScore(item, query)))
          .where((entry) => entry.value >= 0)
          .toList();

      results.sort((a, b) => b.value.compareTo(a.value));

      expect(results[0].key.station["Name"], equals("Narela Terminal"));
      expect(results[0].value, greaterThanOrEqualTo(10000.0)); // Exact match score
    });

    test('Query "polise" matches "Police Station Narela" fuzzily', () {
      const query = "polise"; // Typo for "police"

      final results = searchItems
          .map((item) => MapEntry(item, calculateScore(item, query)))
          .where((entry) => entry.value >= 0)
          .toList();

      results.sort((a, b) => b.value.compareTo(a.value));

      expect(results.length, equals(1));
      expect(results[0].key.station["Name"], equals("Police Station Narela"));
    });
  });
}
