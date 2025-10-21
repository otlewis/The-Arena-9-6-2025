import 'package:flutter/material.dart';
import 'package:animated_emoji/animated_emoji.dart';
import '../widgets/floating_reaction_overlay.dart';

/// Helper function to map emoji strings to AnimatedEmojiData
AnimatedEmojiData getAnimatedEmojiFromString(String emoji) {
  final emojiMap = {
    '👍': AnimatedEmojis.thumbsUp,
    '❤️': AnimatedEmojis.redHeart,
    '😂': AnimatedEmojis.laughing,
    '🎉': AnimatedEmojis.partyPopper,
    '🔥': AnimatedEmojis.fire,
    '👏': AnimatedEmojis.clap.medium,
    '🙌': AnimatedEmojis.raisingHands.medium,
    '💯': AnimatedEmojis.oneHundred,
  };
  return emojiMap[emoji] ?? AnimatedEmojis.thumbsUp;
}

/// Test screen for the floating reaction animation
///
/// To test: Add a button to your home screen that navigates here:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (context) => ReactionAnimationTestScreen(),
/// ));
/// ```
class ReactionAnimationTestScreen extends StatefulWidget {
  const ReactionAnimationTestScreen({super.key});

  @override
  State<ReactionAnimationTestScreen> createState() => _ReactionAnimationTestScreenState();
}

class _ReactionAnimationTestScreenState extends State<ReactionAnimationTestScreen> {
  final List<Widget> _floatingReactions = [];

  // Simulated avatar positions (like speaker panel slots)
  final List<Map<String, dynamic>> _avatars = [
    {'name': 'Alice', 'position': const Offset(100, 200), 'avatar': '👩'},
    {'name': 'Bob', 'position': const Offset(250, 200), 'avatar': '👨'},
    {'name': 'Charlie', 'position': const Offset(100, 350), 'avatar': '🧑'},
    {'name': 'Diana', 'position': const Offset(250, 350), 'avatar': '👩‍🦰'},
  ];

  final List<String> _emojis = ['👍', '❤️', '😂', '🎉', '🔥', '👏', '🙌', '💯'];

  void _sendReactionTo(int avatarIndex, String emoji) {
    final avatar = _avatars[avatarIndex];
    final position = avatar['position'] as Offset;

    setState(() {
      _floatingReactions.add(
        FloatingReactionOverlay(
          key: UniqueKey(),
          emoji: getAnimatedEmojiFromString(emoji),
          startPosition: position,
          duration: const Duration(milliseconds: 2500),
          maxHeight: 180,
        ),
      );
    });

    // Remove after animation completes
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          if (_floatingReactions.isNotEmpty) {
            _floatingReactions.removeAt(0);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Reaction Animation Test'),
        backgroundColor: Colors.purple,
      ),
      body: Stack(
        children: [
          // Instructions
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Tap an avatar, then pick an emoji below.\n'
                'The emoji will float up from the avatar!',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Simulated avatars (speaker panel slots)
          ..._avatars.asMap().entries.map((entry) {
            final index = entry.key;
            final avatar = entry.value;
            final position = avatar['position'] as Offset;

            return Positioned(
              left: position.dx,
              top: position.dy,
              child: GestureDetector(
                onTap: () => _showReactionPicker(index),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple.shade700,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          avatar['avatar'],
                          style: const TextStyle(fontSize: 32),
                        ),
                        Text(
                          avatar['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Floating reactions overlay
          ..._floatingReactions,

          // Emoji picker at bottom
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Quick Reactions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _emojis.map((emoji) {
                      return ReactionButton(
                        emoji: getAnimatedEmojiFromString(emoji),
                        onPressed: () {
                          // Send to a random avatar for demo
                          _sendReactionTo(0, emoji);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(int avatarIndex) {
    final avatar = _avatars[avatarIndex];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send reaction to ${avatar['name']} ${avatar['avatar']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _emojis.map((emoji) {
                return ReactionButton(
                  emoji: getAnimatedEmojiFromString(emoji),
                  onPressed: () {
                    Navigator.pop(context);
                    _sendReactionTo(avatarIndex, emoji);
                  },
                );
              }).toList(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }
}
