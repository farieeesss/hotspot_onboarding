import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/experience.dart';
import '../state/onboarding_state.dart';
import 'onboarding_question_screen.dart';

const List<double> _greyScaleMatrix = <double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class ExperienceSelectionScreen extends ConsumerStatefulWidget {
  const ExperienceSelectionScreen({super.key});

  @override
  ConsumerState<ExperienceSelectionScreen> createState() =>
      _ExperienceSelectionScreenState();
}

class _ExperienceSelectionScreenState
    extends ConsumerState<ExperienceSelectionScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  static const int maxChars = 250;
  bool _isTextFieldFocused = false;
  bool _suppressAnimation = false;

  @override
  void initState() {
    super.initState();
    _textFieldFocusNode.addListener(() {
      setState(() {
        _isTextFieldFocused = _textFieldFocusNode.hasFocus;
      });
    });
  }

  void _resetEverything() {
    // Dismiss keyboard first to avoid layout jumps
    FocusScope.of(context).unfocus();
    // Temporarily suppress spacer animations to prevent brief overflow flash
    _suppressAnimation = true;
    setState(() {
      _controller.clear();
      _textFieldFocusNode.unfocus();
      _isTextFieldFocused = false;
    });
    // Re-enable animations on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _suppressAnimation = false;
      });
    });
    // Reset the description and clear all card selections
    final selectionNotifier = ref.read(experienceSelectionProvider.notifier);
    selectionNotifier.clearSelection();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = ref.watch(experienceSelectionProvider);
    final selectionNotifier = ref.read(experienceSelectionProvider.notifier);
    final experiencesAsync = ref.watch(experiencesProvider);
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bool keyboardVisible = keyboardInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.colorScheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          child: AppBar(
            backgroundColor: const Color(0x05FFFFFF),
            elevation: 0,
            leading: const Icon(Icons.arrow_back),
            title: SvgPicture.asset(
              'assets/appbarline1.svg',
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _resetEverything,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: keyboardInset + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                    duration: _suppressAnimation
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    height: (_isTextFieldFocused || keyboardVisible) ? 8 : 230),
                AnimatedDefaultTextStyle(
                  duration: _suppressAnimation
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: _isTextFieldFocused ? 14 : 24,
                    height: _isTextFieldFocused ? 1.0 : 32 / 24,
                    letterSpacing: _isTextFieldFocused ? 0 : -0.48,
                  ),
                  child: Text(
                    'What kind of experiences do you want to host?',
                    maxLines: _isTextFieldFocused ? 1 : null,
                    overflow:
                        _isTextFieldFocused ? TextOverflow.ellipsis : null,
                  ),
                ),
                AnimatedContainer(
                  duration: _suppressAnimation
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  height: _isTextFieldFocused ? 8 : 16,
                ),
                experiencesAsync.when(
                  data: (list) {
                    if (selection.experiences.isEmpty) {
                      // seed list into state once
                      Future.microtask(
                        () => selectionNotifier.setExperiences(list),
                      );
                    }
                    final items = selection.experiences.isEmpty
                        ? list
                        : selection.experiences;
                    if (items.isEmpty) {
                      return const SizedBox(
                        height: 130,
                        child: Center(child: Text('No experiences found')),
                      );
                    }
                    return SizedBox(
                      height: 130,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: List.generate(items.length, (index) {
                            final exp = items[index];
                            final selected =
                                selection.selectedIds.contains(exp.id);
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < items.length - 1 ? 12 : 0,
                              ),
                              child: _ExperienceCard(
                                experience: exp,
                                selected: selected,
                                index: index,
                                onTap: () =>
                                    selectionNotifier.toggleSelection(exp),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                  error: (e, st) => SizedBox(
                    height: 130,
                    child:
                        Center(child: Text('Failed to load experiences\n$e')),
                  ),
                  loading: () => const SizedBox(
                    height: 130,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                const SizedBox(height: 8),
                _TextWithCounter(
                  controller: _controller,
                  focusNode: _textFieldFocusNode,
                  onChanged: (t) => selectionNotifier.setDescription(t),
                  maxChars: maxChars,
                  hint: '/ Describe your perfect hotspot',
                ),
                const SizedBox(height: 12),
                Center(
                  child: _NextButton(
                    hasSelection: selection.selectedIds.isNotEmpty,
                    onPressed: () {
                      // Log state
                      final ids = selection.selectedIds.toList();
                      // ignore: avoid_print
                      print(
                        'Selected IDs: $ids, text: ${selection.description}',
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingQuestionScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  final Experience experience;
  final bool selected;
  final int index;
  final VoidCallback onTap;
  const _ExperienceCard({
    required this.experience,
    required this.selected,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Convert 3 degrees to radians: 3 * π / 180
    final double angle =
        (index % 2 == 0) ? -3 * 3.14159 / 180 : 3 * 3.14159 / 180;
    return SizedBox(
      width: 130,
      height: 130,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Transform.rotate(
            angle: angle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: Colors.white.withOpacity(selected ? .26 : .12),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(selected ? .32 : .18),
                    blurRadius: selected ? 18 : 10,
                    spreadRadius: selected ? 1.2 : 0.4,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: ColorFiltered(
                  colorFilter: selected
                      ? const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.srcOver,
                        )
                      : const ColorFilter.matrix(_greyScaleMatrix),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        experience.imageUrl,
                        fit: BoxFit.cover,
                      ),
                      if (!selected)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(.55),
                                Colors.black.withOpacity(.35),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextWithCounter extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int maxChars;
  final String hint;
  final ValueChanged<String> onChanged;
  const _TextWithCounter({
    required this.controller,
    this.focusNode,
    required this.maxChars,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: maxChars,
          maxLines: 4,
          minLines: 3,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0x29FFFFFF),
            ),
            counterText: '',
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${controller.text.characters.length}/$maxChars',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(.48),
            ),
          ),
        ),
      ],
    );
  }
}

class _NextButton extends StatelessWidget {
  final bool hasSelection;
  final VoidCallback onPressed;

  const _NextButton({
    required this.hasSelection,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = hasSelection ? 1.0 : 0.3;

    return SizedBox(
      width: 358,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.0804),
                  radius: 2.9553,
                  colors: [
                    const Color(0xFF222222).withOpacity(0.4),
                    const Color(0xFF999999).withOpacity(0.4),
                    const Color(0xFF222222).withOpacity(0.4),
                  ],
                  stops: const [0.0, 0.4987, 1.0],
                ),
                border: Border.all(
                  width: 1,
                  color: Colors.transparent,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    width: 1,
                    color: Colors.transparent,
                  ),
                ),
                child: Stack(
                  children: [
                    // Gradient border using a workaround
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            // 319.95 degrees: convert to alignment
                            // Using approximate direction for the gradient
                            begin: const Alignment(-0.7, -0.7),
                            end: const Alignment(0.7, 0.7),
                            colors: [
                              const Color(0xFF101010).withOpacity(0.5),
                              const Color(0xFFFFFFFF).withOpacity(0.5),
                            ],
                            stops: const [0.0676, 0.9407],
                          ),
                        ),
                      ),
                    ),
                    // Inner container to create border effect
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: RadialGradient(
                              center: const Alignment(0.0, 0.0804),
                              radius: 2.9553,
                              colors: [
                                const Color(0xFF222222).withOpacity(0.4),
                                const Color(0xFF999999).withOpacity(0.4),
                                const Color(0xFF222222).withOpacity(0.4),
                              ],
                              stops: const [0.0, 0.4987, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Button content
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: hasSelection ? onPressed : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Next',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Align(
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  'assets/NextArrow.svg',
                                  height: 16,
                                  width: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
