class Gift {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int cost; // in coins
  final GiftCategory category;
  final GiftTier tier;
  final bool hasVisualEffect;
  final bool hasProfileBadge;
  final bool isLimitedTime;

  const Gift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.cost,
    required this.category,
    required this.tier,
    this.hasVisualEffect = false,
    this.hasProfileBadge = false,
    this.isLimitedTime = false,
  });

  factory Gift.fromMap(Map<String, dynamic> map) {
    return Gift(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      emoji: map['emoji'] ?? '',
      description: map['description'] ?? '',
      cost: map['cost'] ?? 0,
      category: GiftCategory.values.firstWhere(
        (cat) => cat.name == map['category'],
        orElse: () => GiftCategory.intellectual,
      ),
      tier: GiftTier.values.firstWhere(
        (tier) => tier.name == map['tier'],
        orElse: () => GiftTier.basic,
      ),
      hasVisualEffect: map['hasVisualEffect'] ?? false,
      hasProfileBadge: map['hasProfileBadge'] ?? false,
      isLimitedTime: map['isLimitedTime'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'cost': cost,
      'category': category.name,
      'tier': tier.name,
      'hasVisualEffect': hasVisualEffect,
      'hasProfileBadge': hasProfileBadge,
      'isLimitedTime': isLimitedTime,
    };
  }
}

enum GiftCategory {
  intellectual,
  supportive,
  fun,
  recognition,
  interactive,
  premium,
}

enum GiftTier {
  basic,      // 1-5 coins
  standard,   // 5-15 coins
  premium,    // 15-50 coins
  legendary,  // 50+ coins
}

class GiftConstants {
  static const List<Gift> allGifts = [
    // INTELLECTUAL ACHIEVEMENT GIFTS
    Gift(
      id: 'brain_power',
      name: 'Brain Power',
      emoji: '🧠',
      description: 'For brilliant arguments',
      cost: 5,
      category: GiftCategory.intellectual,
      tier: GiftTier.standard,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'bullseye',
      name: 'Bullseye',
      emoji: '🎯',
      description: 'For hitting the point perfectly',
      cost: 8,
      category: GiftCategory.intellectual,
      tier: GiftTier.standard,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'lightbulb_moment',
      name: 'Lightbulb Moment',
      emoji: '💡',
      description: 'For insightful ideas',
      cost: 3,
      category: GiftCategory.intellectual,
      tier: GiftTier.basic,
    ),
    Gift(
      id: 'fire_logic',
      name: 'Fire Logic',
      emoji: '🔥',
      description: 'For compelling reasoning',
      cost: 10,
      category: GiftCategory.intellectual,
      tier: GiftTier.standard,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'devils_advocate',
      name: "Devil's Advocate",
      emoji: '🎭',
      description: 'For good counterarguments',
      cost: 12,
      category: GiftCategory.intellectual,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'scholar',
      name: 'Scholar',
      emoji: '📚',
      description: 'For well-researched points',
      cost: 15,
      category: GiftCategory.intellectual,
      tier: GiftTier.premium,
      hasProfileBadge: true,
    ),
    Gift(
      id: 'debate_champion',
      name: 'Debate Champion',
      emoji: '🏆',
      description: 'Premium gift for exceptional performance',
      cost: 25,
      category: GiftCategory.intellectual,
      tier: GiftTier.premium,
      hasVisualEffect: true,
      hasProfileBadge: true,
    ),

    // SUPPORTIVE & ENCOURAGING GIFTS
    Gift(
      id: 'standing_ovation',
      name: 'Standing Ovation',
      emoji: '👏',
      description: 'For impressive speeches',
      cost: 6,
      category: GiftCategory.supportive,
      tier: GiftTier.standard,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'mic_drop',
      name: 'Mic Drop',
      emoji: '🎤',
      description: 'For ending with impact',
      cost: 12,
      category: GiftCategory.supportive,
      tier: GiftTier.standard,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'respectful_disagreement',
      name: 'Respectful Disagreement',
      emoji: '🤝',
      description: 'For civil discourse',
      cost: 4,
      category: GiftCategory.supportive,
      tier: GiftTier.basic,
    ),
    Gift(
      id: 'peacemaker',
      name: 'Peacemaker',
      emoji: '🕊️',
      description: 'For finding common ground',
      cost: 8,
      category: GiftCategory.supportive,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'rising_star',
      name: 'Rising Star',
      emoji: '🌟',
      description: 'For promising new debaters',
      cost: 7,
      category: GiftCategory.supportive,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'diamond_point',
      name: 'Diamond Point',
      emoji: '💎',
      description: 'For crystalline clarity',
      cost: 18,
      category: GiftCategory.supportive,
      tier: GiftTier.premium,
      hasVisualEffect: true,
    ),

    // FUN & PERSONALITY GIFTS
    Gift(
      id: 'entertainer',
      name: 'Entertainer',
      emoji: '🎪',
      description: 'For making discussions fun',
      cost: 5,
      category: GiftCategory.fun,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'dramatic_flair',
      name: 'Dramatic Flair',
      emoji: '🎭',
      description: 'For passionate delivery',
      cost: 6,
      category: GiftCategory.fun,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'fact_checker',
      name: 'Fact Checker',
      emoji: '🦾',
      description: 'For bringing receipts',
      cost: 9,
      category: GiftCategory.fun,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'detective',
      name: 'Detective',
      emoji: '🔍',
      description: 'For uncovering details',
      cost: 7,
      category: GiftCategory.fun,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'creative_thinker',
      name: 'Creative Thinker',
      emoji: '🎨',
      description: 'For unique perspectives',
      cost: 8,
      category: GiftCategory.fun,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'game_changer',
      name: 'Game Changer',
      emoji: '🚀',
      description: 'For shifting the conversation',
      cost: 15,
      category: GiftCategory.fun,
      tier: GiftTier.premium,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'quick_wit',
      name: 'Quick Wit',
      emoji: '⚡',
      description: 'For fast, clever responses',
      cost: 5,
      category: GiftCategory.fun,
      tier: GiftTier.standard,
    ),

    // RECOGNITION & STATUS GIFTS
    Gift(
      id: 'moderators_choice',
      name: "Moderator's Choice",
      emoji: '👑',
      description: 'Expensive, moderator-only gift',
      cost: 50,
      category: GiftCategory.recognition,
      tier: GiftTier.legendary,
      hasVisualEffect: true,
      hasProfileBadge: true,
    ),
    Gift(
      id: 'gold_standard',
      name: 'Gold Standard',
      emoji: '🥇',
      description: 'For exemplary conduct',
      cost: 20,
      category: GiftCategory.recognition,
      tier: GiftTier.premium,
      hasProfileBadge: true,
    ),
    Gift(
      id: 'distinguished_service',
      name: 'Distinguished Service',
      emoji: '🎖️',
      description: 'For community contribution',
      cost: 25,
      category: GiftCategory.recognition,
      tier: GiftTier.premium,
      hasProfileBadge: true,
    ),
    Gift(
      id: 'wisdom_scroll',
      name: 'Wisdom Scroll',
      emoji: '📜',
      description: 'For sharing knowledge',
      cost: 12,
      category: GiftCategory.recognition,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'bridge_builder',
      name: 'Bridge Builder',
      emoji: '🌈',
      description: 'For connecting opposing views',
      cost: 16,
      category: GiftCategory.recognition,
      tier: GiftTier.premium,
    ),
    Gift(
      id: 'professor',
      name: 'Professor',
      emoji: '🎓',
      description: 'For teaching others',
      cost: 18,
      category: GiftCategory.recognition,
      tier: GiftTier.premium,
      hasProfileBadge: true,
    ),

    // INTERACTIVE & ENGAGING GIFTS
    Gift(
      id: 'plot_twist',
      name: 'Plot Twist',
      emoji: '🎲',
      description: 'For surprising turns',
      cost: 10,
      category: GiftCategory.interactive,
      tier: GiftTier.standard,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'spotlight',
      name: 'Spotlight',
      emoji: '🎪',
      description: 'Highlights the message temporarily',
      cost: 15,
      category: GiftCategory.interactive,
      tier: GiftTier.premium,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'wave_maker',
      name: 'Wave Maker',
      emoji: '🌊',
      description: 'For stirring discussion',
      cost: 8,
      category: GiftCategory.interactive,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'mind_changer',
      name: 'Mind Changer',
      emoji: '🔄',
      description: 'For convincing others',
      cost: 14,
      category: GiftCategory.interactive,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'harmony',
      name: 'Harmony',
      emoji: '🎵',
      description: 'For bringing people together',
      cost: 9,
      category: GiftCategory.interactive,
      tier: GiftTier.standard,
    ),
    Gift(
      id: 'justice_scale',
      name: 'Justice Scale',
      emoji: '⚖️',
      description: 'For fair, balanced arguments',
      cost: 11,
      category: GiftCategory.interactive,
      tier: GiftTier.standard,
    ),

    // PREMIUM GIFTS (Higher Cost)
    Gift(
      id: 'parliament',
      name: 'Parliament',
      emoji: '🏛️',
      description: 'Ultimate debate gift',
      cost: 100,
      category: GiftCategory.premium,
      tier: GiftTier.legendary,
      hasVisualEffect: true,
      hasProfileBadge: true,
    ),
    Gift(
      id: 'master_debater',
      name: 'Master Debater',
      emoji: '🎯',
      description: 'Prestigious recognition',
      cost: 75,
      category: GiftCategory.premium,
      tier: GiftTier.legendary,
      hasVisualEffect: true,
      hasProfileBadge: true,
    ),
    Gift(
      id: 'hall_of_fame',
      name: 'Hall of Fame',
      emoji: '🌟',
      description: 'Legendary status',
      cost: 80,
      category: GiftCategory.premium,
      tier: GiftTier.legendary,
      hasVisualEffect: true,
      hasProfileBadge: true,
    ),
    Gift(
      id: 'influence',
      name: 'Influence',
      emoji: '💫',
      description: 'For changing minds',
      cost: 60,
      category: GiftCategory.premium,
      tier: GiftTier.legendary,
      hasVisualEffect: true,
    ),
    Gift(
      id: 'rhetoric_master',
      name: 'Rhetoric Master',
      emoji: '🎭',
      description: 'For persuasive power',
      cost: 70,
      category: GiftCategory.premium,
      tier: GiftTier.legendary,
      hasVisualEffect: true,
      hasProfileBadge: true,
    ),
  ];

  // Helper methods to filter gifts
  static List<Gift> getGiftsByCategory(GiftCategory category) {
    return allGifts.where((gift) => gift.category == category).toList();
  }

  static List<Gift> getGiftsByTier(GiftTier tier) {
    return allGifts.where((gift) => gift.tier == tier).toList();
  }

  static Gift? getGiftById(String id) {
    try {
      return allGifts.firstWhere((gift) => gift.id == id);
    } catch (e) {
      return null;
    }
  }
} 