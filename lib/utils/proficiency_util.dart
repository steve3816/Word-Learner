import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const List<(int, String)> proficiencyLevels = [
  (0, '非常不熟'),
  (33, '有點不熟'),
  (66, '普通'),
  (100, '很熟練'),
];

String proficiencyAsset(int proficiency) {
  if (proficiency >= 100) return 'assets/icons/emoji_laugh.svg';
  if (proficiency >= 66) return 'assets/icons/smile.svg';
  if (proficiency >= 33) return 'assets/icons/smiley-meh.svg';
  return 'assets/icons/smiley-sad.svg';
}

// Maps any 0-100 value to the nearest level value for button highlight
int proficiencyToLevel(int proficiency) {
  if (proficiency >= 100) return 100;
  if (proficiency >= 66) return 66;
  if (proficiency >= 33) return 33;
  return 0;
}

Widget proficiencyIcon(int proficiency, {double size = 24}) {
  return SvgPicture.asset(
    proficiencyAsset(proficiency),
    width: size,
    height: size,
  );
}
