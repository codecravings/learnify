import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../features/companion/screens/study_companion_screen.dart';
import '../features/battle/screens/battle_lobby_screen.dart';
import '../features/battle/screens/battle_matchmaking_screen.dart';
import '../features/battle/screens/battle_screen.dart';
import '../features/battle/screens/battle_result_screen.dart';
import '../features/challenges/screens/challenge_detail_screen.dart';
import '../features/challenges/screens/create_challenge_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/achievements/screens/achievements_screen.dart';
import '../features/learning_paths/screens/learning_paths_screen.dart';
import '../features/spectator/screens/spectator_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/courses/screens/courses_screen.dart';
import '../features/story_learning/screens/story_screen.dart';
import '../features/story_learning/screens/topic_explorer_screen.dart';
import '../features/story_learning/screens/your_topics_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/knowledge_graph/screens/concept_map_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/peer_help/screens/peer_help_screen.dart';
import '../features/skill_tree/screens/skill_tree_screen.dart';
import '../features/courses/screens/coding_arena_screen.dart';

abstract class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String battleLobby = '/battle/lobby';
  static const String battleMatchmaking = '/battle/matchmaking';
  static const String battle = '/battle/play';
  static const String battleResult = '/battle/result';
  static const String challengeDetail = '/challenge/detail';
  static const String challengeCreate = '/challenge/create';
  static const String forumPost = '/forum/post';
  static const String leaderboard = '/leaderboard';
  static const String achievements = '/achievements';
  static const String learningPaths = '/learning-paths';
  static const String spectator = '/spectator';
  static const String search = '/search';
  static const String userProfile = '/profile';
  static const String onboarding = '/onboarding';
  static const String topicExplorer = '/topic-explorer';
  static const String lesson = '/lesson';
  static const String conceptMap = '/concept-map';
  static const String peerHelp = '/peer-help';
  static const String skillTree = '/skill-tree';
  static const String codingArena = '/coding-arena';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final isGoingToAuth = state.matchedLocation == AppRoutes.splash ||
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.onboarding;

      if (!isLoggedIn && !isGoingToAuth) {
        return AppRoutes.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Home shell (bottom nav) ────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeDashboard(),
          ),
          GoRoute(
            path: '/home/feed',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: '/home/companion',
            builder: (context, state) => const StudyCompanionScreen(),
          ),
          GoRoute(
            path: '/home/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // ── Battle ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.battleLobby,
        builder: (context, state) => const BattleLobbyScreen(),
      ),
      GoRoute(
        path: AppRoutes.battleMatchmaking,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BattleMatchmakingScreen(
            mode: extra['mode'] as String? ?? 'speed_solve',
            modeName: extra['modeName'] as String? ?? 'Speed Solve',
            modeColor: extra['modeColor'] as Color? ?? const Color(0xFF3B82F6),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.battle,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BattleScreen(
            battleId: extra['battleId'] as String? ?? '',
            mode: extra['mode'] as String? ?? 'speed_solve',
            modeColor: extra['modeColor'] as Color? ?? const Color(0xFF3B82F6),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.battleResult,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BattleResultScreen(
            battleId: extra['battleId'] as String? ?? '',
            playerScore: extra['playerScore'] as int? ?? 0,
            opponentScore: extra['opponentScore'] as int? ?? 0,
            playerTime: extra['playerTime'] as int? ?? 0,
            opponentTime: extra['opponentTime'] as int? ?? 0,
            won: extra['won'] as bool? ?? false,
            xpEarned: extra['xpEarned'] as int? ?? 0,
            eloChange: extra['eloChange'] as int? ?? 0,
            modeColor: extra['modeColor'] as Color? ?? const Color(0xFF3B82F6),
          );
        },
      ),

      // ── Challenges ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.challengeCreate,
        builder: (context, state) => const CreateChallengeScreen(),
      ),
      GoRoute(
        path: AppRoutes.challengeDetail,
        builder: (context, state) {
          // Pass ChallengeModel via extra
          final challenge = state.extra;
          return ChallengeDetailScreen(challenge: challenge);
        },
      ),

      // ── Standalone screens ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.learningPaths,
        builder: (context, state) => const LearningPathsScreen(),
      ),
      GoRoute(
        path: AppRoutes.spectator,
        builder: (context, state) => const SpectatorScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/courses',
        builder: (context, state) => const CoursesScreen(),
      ),
      // ── Your Topics ───────────────────────────────────────────────
      GoRoute(
        path: '/topics',
        builder: (context, state) => const YourTopicsScreen(),
      ),
      // ── Peer Help (Ask & Answer) ──────────────────────────────
      GoRoute(
        path: AppRoutes.peerHelp,
        builder: (context, state) => const PeerHelpScreen(),
      ),
      // ── Skill Tree ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.skillTree,
        builder: (context, state) => const SkillTreeScreen(),
      ),
      // ── Concept Map (Knowledge Graph) ───────────────────────────
      GoRoute(
        path: AppRoutes.conceptMap,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ConceptMapScreen(
            focusConcept: extra['focusConcept'] as String?,
          );
        },
      ),
      // ── Topic Explorer (Learn Anything breakdown) ────────────────
      GoRoute(
        path: AppRoutes.topicExplorer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return TopicExplorerScreen(
            topic: extra['topic'] as String? ?? '',
          );
        },
      ),
      // ── All lessons → Story Learning ──────────────────────────────
      GoRoute(
        path: AppRoutes.lesson,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return StoryScreen(
            lessonId: extra['lessonId'] as String? ?? '',
            subjectId: extra['subjectId'] as String? ?? '',
            chapterId: extra['chapterId'] as String? ?? '',
            customTopic: extra['customTopic'] as String?,
            preselectedLevel: extra['level'] as String?,
          );
        },
      ),
      // ── Coding Arena ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.codingArena,
        builder: (context, state) => const CodingArenaScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatDetailScreen(
            chatId: extra['chatId'] as String? ?? '',
            otherUsername: extra['otherUsername'] as String? ?? 'User',
          );
        },
      ),
    ],
  );
});
