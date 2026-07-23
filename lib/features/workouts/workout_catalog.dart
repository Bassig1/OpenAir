import 'package:flutter/material.dart';

/// Activity catalog for browse + matching.
class WorkoutCatalog {
  static const activities = <WorkoutActivityType>[
    WorkoutActivityType('Run', Icons.directions_run, 'Cardio'),
    WorkoutActivityType('Walk', Icons.directions_walk, 'Cardio'),
    WorkoutActivityType('Hike', Icons.terrain, 'Cardio'),
    WorkoutActivityType('Trail Run', Icons.forest, 'Cardio'),
    WorkoutActivityType('Treadmill', Icons.directions_run, 'Cardio'),
    WorkoutActivityType('Elliptical', Icons.fitness_center, 'Cardio'),
    WorkoutActivityType('Stair Climber', Icons.stairs, 'Cardio'),
    WorkoutActivityType('Bike', Icons.directions_bike, 'Cardio'),
    WorkoutActivityType('Spinning', Icons.pedal_bike, 'Cardio'),
    WorkoutActivityType('Outdoor Bike', Icons.directions_bike, 'Cardio'),
    WorkoutActivityType('Swim', Icons.pool, 'Cardio'),
    WorkoutActivityType('Open Water Swim', Icons.water, 'Cardio'),
    WorkoutActivityType('Rowing', Icons.rowing, 'Cardio'),
    WorkoutActivityType('Kayaking', Icons.kayaking, 'Cardio'),
    WorkoutActivityType('Weight Training', Icons.fitness_center, 'Strength'),
    WorkoutActivityType('Circuit Training', Icons.repeat, 'Strength'),
    WorkoutActivityType('HIIT', Icons.flash_on, 'Strength'),
    WorkoutActivityType('Bootcamp', Icons.sports_mma, 'Strength'),
    WorkoutActivityType('CrossFit', Icons.sports_gymnastics, 'Strength'),
    WorkoutActivityType('Yoga', Icons.self_improvement, 'Mind & Body'),
    WorkoutActivityType('Pilates', Icons.accessibility_new, 'Mind & Body'),
    WorkoutActivityType('Meditation', Icons.spa, 'Mind & Body'),
    WorkoutActivityType('Breathwork', Icons.air, 'Mind & Body'),
    WorkoutActivityType('Stretching', Icons.accessibility, 'Mind & Body'),
    WorkoutActivityType('Martial Arts', Icons.sports_kabaddi, 'Sports'),
    WorkoutActivityType('Boxing', Icons.sports_mma, 'Sports'),
    WorkoutActivityType('Basketball', Icons.sports_basketball, 'Sports'),
    WorkoutActivityType('Soccer', Icons.sports_soccer, 'Sports'),
    WorkoutActivityType('Tennis', Icons.sports_tennis, 'Sports'),
    WorkoutActivityType('Golf', Icons.golf_course, 'Sports'),
    WorkoutActivityType('Ski', Icons.downhill_skiing, 'Sports'),
    WorkoutActivityType('Snowboard', Icons.snowboarding, 'Sports'),
    WorkoutActivityType('Skateboarding', Icons.skateboarding, 'Sports'),
    WorkoutActivityType('Dance', Icons.nightlife, 'Sports'),
    WorkoutActivityType('Aerobics', Icons.sports, 'Cardio'),
    WorkoutActivityType('Interval Workout', Icons.timeline, 'Cardio'),
    WorkoutActivityType('Sport', Icons.emoji_events, 'Sports'),
    WorkoutActivityType('Workout', Icons.fitness_center, 'General'),
    WorkoutActivityType('Outdoor Workout', Icons.park, 'General'),
    WorkoutActivityType('Indoor Cardio', Icons.cottage, 'Cardio'),
  ];

  static List<String> get categories {
    final set = activities.map((a) => a.category).toSet().toList()..sort();
    return set;
  }
}

class WorkoutActivityType {
  const WorkoutActivityType(this.name, this.icon, this.category);
  final String name;
  final IconData icon;
  final String category;
}
