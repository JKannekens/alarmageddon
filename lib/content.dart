import 'dart:math';

import 'models.dart';

final rng = Random();

T pick<T>(List<T> items) => items[rng.nextInt(items.length)];

/// Near-rhymes for the sing-on-beat challenge. Mild sticks to the easier pairs.
const rhymePairs = [
  ['Carrot', 'Parrot'],
  ['Bake', 'Cake'],
  ['Sheep', 'Ship'],
  ['Pickle', 'Tickle'],
  ['Moon', 'Spoon'],
  ['Bread', 'Bed'],
  ['Fox', 'Socks'],
  ['Mouse', 'House'],
  ['Beard', 'Weird'],
];
const _mildPairs = 4;

/// Eight words from one pair, mixed enough that you can't coast on a pattern.
List<String> generateBeatWords(Difficulty diff) {
  final pool = diff == Difficulty.mild ? rhymePairs.take(_mildPairs).toList() : rhymePairs;
  final pair = pick(pool);
  while (true) {
    final words = List.generate(8, (_) => pair[rng.nextBool() ? 0 : 1]);
    final sorted = [...words]..sort();
    final distinct = words.toSet().length > 1;
    final notSorted = words.join() != sorted.join() && words.join() != sorted.reversed.join();
    if (distinct && notSorted) return words;
  }
}

const scanObjects = [
  'a cup',
  'the sink',
  'your toothbrush',
  'a shoe',
  'the fridge',
  'a spoon',
  'a towel',
];

class MathQuestion {
  const MathQuestion(this.text, this.answer);
  final String text;
  final int answer;
}

MathQuestion generateMath(Difficulty diff) {
  final big = diff == Difficulty.apocalyptic;
  final mild = diff == Difficulty.mild;
  final a = mild ? 3 + rng.nextInt(7) : 6 + rng.nextInt(big ? 20 : 12);
  final b = 3 + rng.nextInt(big ? 9 : 6);
  final c = 2 + rng.nextInt(30);
  return MathQuestion('$a × $b + $c', a * b + c);
}

const roasts = {
  RoastLevel.mild: [
    'Good morning! Time to get up.',
    'Rise and shine. Mostly rise.',
    'The day is waiting. Politely.',
  ],
  RoastLevel.savage: [
    "Get up. The bed isn't paying rent.",
    "Snooze isn't an option. You knew that when you installed me.",
    "Your future self called. They're disappointed.",
  ],
  RoastLevel.unhinged: [
    'I will ring until the sun burns out.',
    'Every second you lie there, a parrot loses its carrot.',
    'Wake up or I start texting your mum.',
  ],
};

const beatFailRoasts = [
  'Embarrassing for both of us.',
  'Your tongue filed a complaint.',
  'Try using your mouth this time.',
  "Bold strategy. Didn't work.",
];

const beatHitCheers = ['Nice.', 'On it.', 'Clean.', 'Again.', 'Okay, singer.'];

const mathWrong = [
  'Wrong. Your brain is still asleep.',
  'Nope. Try counting on fingers.',
  "Incorrect. Coffee can't save you.",
];

String successRoast(int secs) => secs < 60
    ? 'Annoyingly efficient.'
    : secs < 180
        ? 'Acceptable. Barely.'
        : 'I aged waiting.';

const difficultyNotes = {
  Difficulty.mild: 'Easy words, small sums. For people with feelings.',
  Difficulty.spicy: 'The default. Mildly humiliating.',
  Difficulty.apocalyptic: 'Faster beat, bigger sums, 50 shakes. No mercy.',
};
