import 'package:flutter/material.dart';

enum ProficiencyLevel {
  veryUnfamiliar(score: 0,   label: '非常不熟', icon: Icons.sentiment_very_dissatisfied_outlined),
  unfamiliar    (score: 30,  label: '有點不熟', icon: Icons.sentiment_neutral_outlined),
  neutral       (score: 60,  label: '普通',     icon: Icons.sentiment_satisfied_outlined),
  proficient    (score: 100, label: '非常熟練',   icon: Icons.sentiment_very_satisfied_outlined);

  const ProficiencyLevel({
    required this.score,
    required this.label,
    required this.icon,
  });

  final int score;
  final String label;
  final IconData icon;

  static ProficiencyLevel fromScore(int score) {
    if (score >= proficient.score) return ProficiencyLevel.proficient;
    if (score >= neutral.score)  return ProficiencyLevel.neutral;
    if (score >= unfamiliar.score)  return ProficiencyLevel.unfamiliar;
    return ProficiencyLevel.veryUnfamiliar;
  }

}

Widget proficiencyIcon(int score, {double size = 24}) =>
    Icon(ProficiencyLevel.fromScore(score).icon, size: size);
