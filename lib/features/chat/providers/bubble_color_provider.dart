import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BubbleColorNotifier extends StateNotifier<Color?> {
  final String conversationId;

  BubbleColorNotifier(this.conversationId) : super(null) {
    _load();
  }

  static String _key(String id) => 'bubble_color_$id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_key(conversationId));
    if (value != null) state = Color(value);
  }

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(conversationId), color.toARGB32());
  }

  Future<void> reset() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(conversationId));
  }
}

final bubbleColorProvider = StateNotifierProvider.family<BubbleColorNotifier, Color?, String>(
  (ref, conversationId) => BubbleColorNotifier(conversationId),
);
