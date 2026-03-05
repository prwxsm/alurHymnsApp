import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_db_service.dart';
import 'hymn_provider.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this.ref) : super(SettingsState(isDarkMode: false, fontSize: 18.0)) {
    _loadSettings();
  }

  final Ref ref;

  void _loadSettings() {
    final localDb = ref.read(localDbProvider);
    final box = localDb.settingsBox;
    final isDarkMode = box.get('isDarkMode', defaultValue: false);
    final fontSize = box.get('fontSize', defaultValue: 18.0);
    
    state = SettingsState(isDarkMode: isDarkMode, fontSize: fontSize);
  }

  Future<void> toggleTheme() async {
    final localDb = ref.read(localDbProvider);
    final newState = !state.isDarkMode;
    await localDb.settingsBox.put('isDarkMode', newState);
    state = state.copyWith(isDarkMode: newState);
  }

  Future<void> setFontSize(double newSize) async {
    final localDb = ref.read(localDbProvider);
    await localDb.settingsBox.put('fontSize', newSize);
    state = state.copyWith(fontSize: newSize);
  }

  Future<void> increaseFontSize() async {
    final localDb = ref.read(localDbProvider);
    final newSize = (state.fontSize + 2.0).clamp(12.0, 36.0);
    await localDb.settingsBox.put('fontSize', newSize);
    state = state.copyWith(fontSize: newSize);
  }

  Future<void> decreaseFontSize() async {
    final localDb = ref.read(localDbProvider);
    final newSize = (state.fontSize - 2.0).clamp(12.0, 36.0);
    await localDb.settingsBox.put('fontSize', newSize);
    state = state.copyWith(fontSize: newSize);
  }
}

class SettingsState {
  final bool isDarkMode;
  final double fontSize;

  SettingsState({required this.isDarkMode, required this.fontSize});

  SettingsState copyWith({bool? isDarkMode, double? fontSize}) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
