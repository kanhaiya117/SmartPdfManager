class TextSummarizer {
  const TextSummarizer();

  String summarize(String source, {int maximumSentences = 4}) {
    final text = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';

    final sentences = text
        .split(RegExp(r'(?<=[.!?।])\s+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.length > 15)
        .toList();
    if (sentences.length <= maximumSentences) return text;

    final frequencies = <String, int>{};
    for (final word in _words(text)) {
      if (word.length < 3 || _stopWords.contains(word)) continue;
      frequencies.update(word, (count) => count + 1, ifAbsent: () => 1);
    }

    final ranked = <({int index, double score, String sentence})>[];
    for (var index = 0; index < sentences.length; index++) {
      final words = _words(
        sentences[index],
      ).where((word) => !_stopWords.contains(word)).toList();
      if (words.isEmpty) continue;
      final frequencyScore =
          words.fold<int>(
            0,
            (score, word) => score + (frequencies[word] ?? 0),
          ) /
          words.length;
      final positionBonus = index == 0 ? 1.35 : 1 / (index + 2);
      ranked.add((
        index: index,
        score: frequencyScore + positionBonus,
        sentence: sentences[index],
      ));
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    final selected = ranked.take(maximumSentences).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return selected.map((item) => item.sentence).join(' ');
  }

  Iterable<String> _words(String value) sync* {
    for (final raw in value.toLowerCase().split(RegExp(r'\s+'))) {
      final word = raw.replaceAll(
        RegExp(r'''^[^\w\u0900-\u097F]+|[^\w\u0900-\u097F]+$'''),
        '',
      );
      if (word.isNotEmpty) yield word;
    }
  }

  static const _stopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'has',
    'he',
    'in',
    'is',
    'it',
    'its',
    'of',
    'on',
    'that',
    'the',
    'to',
    'was',
    'were',
    'will',
    'with',
    'this',
    'these',
    'those',
    'or',
    'but',
    'है',
    'और',
    'का',
    'की',
    'के',
    'को',
    'में',
    'से',
    'पर',
    'यह',
    'था',
    'हैं',
  };
}
