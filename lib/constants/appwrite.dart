class AppwriteConstants {
  static const String projectId = "683a37a8003719978879";  // Arena Debate App project where all collections exist
  static const String endpoint = "https://cloud.appwrite.io/v1";
  static const String databaseId = "arena_db";
  
  // Collection IDs
  static const String usersCollection = "users";
  static const String debateClubsCollection = "debate_clubs";
  static const String membershipsCollection = "memberships";
  static const String roomsCollection = "discussion_rooms";
  static const String roomParticipantsCollection = "room_participants";
  static const String debateDiscussionRoomsCollection = "debate_discussion_rooms";
  static const String debateDiscussionParticipantsCollection = "debate_discussion_participants";
  static const String arenaParticipantsCollection = "arena_participants";
  static const String arenaEmailsCollection = "arena_emails";
  static const String emailTemplatesCollection = "email_templates";
  static const String emailDraftsCollection = "email_drafts";
  static const String moderatorsCollection = "moderators";
  static const String judgesCollection = "judges";
  static const String pingRequestsCollection = "ping_requests";
  static const String moderatorJudgeRatingsCollection = "moderator_judge_ratings";
  static const String roomHandRaisesCollection = "room_hand_raises";
  static const String roomSlideStateCollection = "room_slide_state";
  static const String sharedSourcesCollection = "shared_sources";

  
  // Bucket IDs
  static const String profileImagesBucket = "profile_images";
  static const String debateSlidesBucket = "debate_slides";
} 