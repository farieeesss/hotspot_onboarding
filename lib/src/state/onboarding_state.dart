import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/experience.dart';
import '../services/experience_service.dart';

// Service provider
final experienceServiceProvider = Provider<ExperienceService>((ref) {
  return ExperienceService();
});

// Experiences list provider
final experiencesProvider = FutureProvider<List<Experience>>((ref) async {
  final service = ref.read(experienceServiceProvider);
  return service.fetchExperiences();
});

// Selection and text state
class ExperienceSelectionState {
  final List<Experience> experiences;
  final Set<int> selectedIds;
  final String description;
  const ExperienceSelectionState({
    this.experiences = const [],
    this.selectedIds = const {},
    this.description = '',
  });

  ExperienceSelectionState copyWith({
    List<Experience>? experiences,
    Set<int>? selectedIds,
    String? description,
  }) {
    return ExperienceSelectionState(
      experiences: experiences ?? this.experiences,
      selectedIds: selectedIds ?? this.selectedIds,
      description: description ?? this.description,
    );
  }
}

class ExperienceSelectionNotifier
    extends StateNotifier<ExperienceSelectionState> {
  ExperienceSelectionNotifier() : super(const ExperienceSelectionState());

  void setExperiences(List<Experience> list) {
    state = state.copyWith(experiences: list);
  }

  void toggleSelection(Experience exp) {
    final selected = Set<int>.from(state.selectedIds);
    if (selected.contains(exp.id)) {
      selected.remove(exp.id);
    } else {
      selected.add(exp.id);
    }
    // Move selected experience to front as per animation requirement (implicit reordering)
    final list = List<Experience>.from(state.experiences);
    list.removeWhere((e) => e.id == exp.id);
    final insertIndex = selected.contains(exp.id)
        ? 0
        : list.indexWhere((e) => (e.order ?? 999) > (exp.order ?? 999));
    list.insert(insertIndex < 0 ? 0 : insertIndex, exp);
    state = state.copyWith(selectedIds: selected, experiences: list);
  }

  void setDescription(String text) {
    state = state.copyWith(description: text);
  }

  void clearSelection() {
    // Create a new state with empty selections and description
    // Keep the experiences list as is (don't reset order)
    final currentExperiences = List<Experience>.from(state.experiences);
    state = ExperienceSelectionState(
      experiences: currentExperiences,
      selectedIds: const <int>{},
      description: '',
    );
  }
}

final experienceSelectionProvider = StateNotifierProvider<
    ExperienceSelectionNotifier, ExperienceSelectionState>((ref) {
  return ExperienceSelectionNotifier();
});

// Onboarding Question State (recordings + text)
class OnboardingAnswerState {
  final String text;
  final String? audioPath;
  final String? videoPath;
  final bool isRecordingAudio;
  const OnboardingAnswerState({
    this.text = '',
    this.audioPath,
    this.videoPath,
    this.isRecordingAudio = false,
  });

  OnboardingAnswerState copyWith({
    String? text,
    String? audioPath,
    String? videoPath,
    bool? isRecordingAudio,
  }) {
    return OnboardingAnswerState(
      text: text ?? this.text,
      audioPath: audioPath ?? this.audioPath,
      videoPath: videoPath ?? this.videoPath,
      isRecordingAudio: isRecordingAudio ?? this.isRecordingAudio,
    );
  }
}

class OnboardingAnswerNotifier extends StateNotifier<OnboardingAnswerState> {
  OnboardingAnswerNotifier() : super(const OnboardingAnswerState());

  void setText(String t) => state = state.copyWith(text: t);

  // Explicitly set (or clear) audioPath even when null
  void setAudio(String? p) => state = OnboardingAnswerState(
        text: state.text,
        audioPath: p,
        videoPath: state.videoPath,
        isRecordingAudio: state.isRecordingAudio,
      );

  // Explicitly set (or clear) videoPath even when null
  void setVideo(String? p) => state = OnboardingAnswerState(
        text: state.text,
        audioPath: state.audioPath,
        videoPath: p,
        isRecordingAudio: state.isRecordingAudio,
      );

  void setRecording(bool r) => state = state.copyWith(isRecordingAudio: r);
}

final onboardingAnswerProvider =
    StateNotifierProvider<OnboardingAnswerNotifier, OnboardingAnswerState>((
  ref,
) {
  return OnboardingAnswerNotifier();
});
