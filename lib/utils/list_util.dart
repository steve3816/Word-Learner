import 'dart:math';

class ListUtil {
  static T getRandomElement<T>(List<T> list, Random random) =>
      list[random.nextInt(list.length)];
}
