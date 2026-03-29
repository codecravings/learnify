# Learnify

**AI Study Companion That Remembers You**

Learnify is a mobile learning app where you type **any topic** and an AI generates an interactive story-based lesson with characters, dialogue, and quizzes — personalized to your learning history using persistent AI memory.

The AI doesn't just teach. It **remembers** what you've studied, what you got wrong, how you scored, and what level you're at. Every lesson adapts based on your past performance. The more you learn, the smarter it gets.

---

## The Problem

Students forget what they struggle with. Traditional study apps are **stateless** — every session starts from zero. The AI has no idea you bombed projectile motion last week or that you already mastered photosynthesis basics. Context windows reset, chat histories vanish, and the student is left managing their own weaknesses manually.

---

## How It Works

Learnify uses **Hindsight Memory** (by Vectorize) as a persistent brain for each student — not a bolt-on, but deeply wired into every learning interaction.

```
Student types "Photosynthesis"
        │
        ▼
  HINDSIGHT REFLECT (structured)
  "Has this student studied this before?"
        │
        ▼
  LEVEL SELECT SCREEN
  AI recommends: Basics / Intermediate / Advanced
  based on past quiz scores & mistakes
        │
        ▼
  HINDSIGHT RECALL
  Fetches: past mistakes, weak concepts, mastered areas
        │
        ▼
  INJECTED INTO AI PROMPT
  DeepSeek generates a PERSONALIZED story
  → More time on weak concepts
  → Skips what's already mastered
  → Quiz targets previous mistakes
        │
        ▼
  Student completes quiz (2/3 correct)
        │
        ▼
  HINDSIGHT RETAIN
  Stores: topic, level, score, missed questions,
  concepts covered, learning style used
        │
        ▼
  NEXT SESSION — AI remembers EVERYTHING
```

---

## Features

### AI-Powered Learning

**Learn Anything** — Type **any topic** — Photosynthesis, Blockchain, WW2, Quantum Physics — and get a personalized lesson. AI detects if you've studied it before and recommends the right difficulty level (Basics / Intermediate / Advanced).

**Story-Based Lessons** — Visual novel-style lessons with AI-generated characters, portraits (DALL-E 3), and typewriter-animated dialogue. Three learning styles:
- **Desi Meme** — Indian humor and relatable references
- **Practical** — Real-world applications and analogies
- **Movie/TV** — Learn through your favorite franchise characters

**Topic Explorer** — AI breaks down any topic into 6-8 sub-topics using Groq. Pick your difficulty, study each one, track completion, and revise.

**AI Study Companion** — A dedicated assistant powered entirely by your learning memory:
- **Study Pulse** — Auto-generated insight about your learning progress
- **Quick Actions** — "What should I study?", "Quiz me on weak spots", "Study plan for this week", "Where am I struggling?"
- **Free-form chat** — Ask anything, get answers informed by your full history
- Every exchange is retained — the companion gets smarter over time

**Structured Courses** — Pre-built courses in Physics, Math, and DSA with interactive games, simulations, and quizzes. More subjects coming soon.

### Social Features

**Social Feed** — Instagram/Twitter-style activity feed where you can:
- **Post updates** — Share text + image posts about your learning
- **React with emojis** — 5 reaction types per post: 🔥 Fire, 🧠 Brain, 👏 Clap, 💯 Perfect, ❤️ Heart (toggle, only one active at a time)
- **All / Following toggle** — Switch between global feed and posts from people you follow
- **Suggested Users** — Horizontal scroll of recommended learners to follow based on shared interests

**Follow System** — Follow other learners to see their posts in your feed. Profiles show follower/following counts, and you can follow/unfollow from any user's profile page.

**Peer Help (Ask & Answer)** — StackOverflow-style Q&A for students:
- Post questions across 7 categories (math, physics, chemistry, biology, coding, logic, general)
- Submit solutions, upvote answers, accept the best one
- Earn XP: +10 for asking, +25 for accepted answer, +5 per upvote
- Tutor badges based on accepted answer count

**Peer Messaging** — Direct chat with other learners via the `/chat` system.

### Gamification

**XP & League System** — Every action earns XP. 6 fantasy-themed league tiers from Apprentice (0 XP) to Supreme Wizard (15,000 XP):
- Solve a challenge: 50 XP | Win a battle: 100 XP | Perfect score: 150 XP
- Complete a story lesson: 35 XP | Help on forum: 20 XP | Daily login: 10 XP
- **Difficulty multipliers**: Easy 1.0x, Medium 1.5x, Hard 2.0x, Expert 3.0x
- **Streak bonus**: +2% per consecutive day, capped at 2.0x
- **Hint penalties**: Each hint used reduces XP (25%, 50%, 75%)

**Knowledge Battles** — Real-time 1v1 competitive battles:
- 3 battle modes: **Speed Solve** (fastest wins), **Mind Trap** (trick questions), **Scenario Battle** (AI-generated scenarios)
- Skill-based matchmaking (±200 rating range)
- 5 rounds per battle with countdown timer
- Winner gets 50+ XP, loser still earns 15+ XP
- **Spectator Mode** — Watch live battles with esports-inspired UI, LIVE indicators, and reaction sidebar

**Leaderboards** — 4 ranking categories with podium display:
- Battle Ranking, XP Champions, Puzzle Creators, Speed Demons
- Filter by All Time / Monthly / Weekly
- Top 100 recalculated hourly by Cloud Functions

**Achievements** — 15+ achievement badges across 4 categories with rarity tiers (Common → Rare → Epic → Legendary):
- **Study**: First Lesson, Knowledge Seeker (5 topics), Topic Master (10), Scholar Elite (25)
- **Quiz**: First Quiz, Perfect Score, Advanced Scholar, Quiz Legend
- **Streak**: Getting Started (3d), Week Warrior (7d), Fortnight Focus (14d), Monthly Master (30d)
- **Special**: Early Adopter, Night Owl, XP Legend (5000 XP)
- Each achievement awards bonus XP and shows progress bars for locked ones

**Daily Challenges** — Fresh challenge every day at 00:00 UTC with XP rewards.

**Streaks & Progress** — Daily streak counter, progress bars, star ratings (1-3) per topic, accuracy percentages, and "Continue Learning" cards on the home dashboard.

### Skill Tree & Knowledge Graph

**Skill Tree** — Interactive visualization of your learning progress:
- Nodes represent topics (locked = gray, in-progress = blue, mastered = green)
- Bezier curve connections between related topics
- Subject filter tabs and overall progress display
- Tap any node for detailed stats and a "Continue Studying" button

**Knowledge Graph** — Concept map explorer for navigating relationships between topics you've studied.

---

## Architecture

### Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter (iOS, Android, Web, Desktop) |
| **Backend** | Firebase — Auth, Firestore, Cloud Functions, Storage |
| **AI Memory** | Hindsight Memory by Vectorize — Retain, Recall, Reflect APIs |
| **Story Generation** | DeepSeek API (OpenAI-compatible) |
| **Challenge AI** | Google Gemini 1.5 Pro/Flash |
| **Image Generation** | OpenAI DALL-E 3 with Pollinations.ai fallback |
| **Sub-topic Generation** | Groq (Llama 3.3 70B) |
| **Navigation** | Go Router |
| **State** | StatefulWidget + setState (Riverpod declared but minimal) |

### Project Structure

```
lib/
├── core/                    # Shared services, theme, widgets, constants
│   ├── services/            # FirebaseService, HindsightService, etc.
│   ├── theme/               # Dark glassmorphism theme system
│   ├── widgets/             # GlassContainer, NeonButton, ParticleBackground
│   ├── constants/           # App constants, asset paths
│   └── utils/               # Validators, XP calculator
│
├── features/                # Feature modules (screens/services/widgets each)
│   ├── auth/                # Login, Register, Splash, Home dashboard
│   ├── story_learning/      # 6-phase story flow, topic explorer, DeepSeek
│   ├── companion/           # AI study companion (Hindsight-powered)
│   ├── courses/             # Course catalogue, interactive games
│   ├── battle/              # Real-time 1v1 battles, matchmaking
│   ├── challenges/          # AI-generated challenges
│   ├── peer_help/           # Ask & answer with XP rewards
│   ├── feed/                # Social feed with reactions & follows
│   ├── skill_tree/          # Visual skill tree visualization
│   ├── knowledge_graph/     # Concept map explorer
│   ├── profile/             # User profile, achievements, stats
│   ├── leaderboard/         # Global & category rankings
│   ├── forum/               # Discussion forum
│   ├── search/              # Topic search with AI
│   ├── chat/                # Peer messaging
│   ├── onboarding/          # First-time user onboarding
│   ├── achievements/        # Achievement cards & detail views
│   ├── learning_paths/      # Guided learning paths
│   └── spectator/           # Watch live battles
│
├── models/                  # Shared data models (UserModel, BattleModel, etc.)
├── routes/                  # Go Router configuration
└── main.dart                # Firebase init, app entry point

functions/                   # Firebase Cloud Functions (TypeScript)
└── src/index.ts             # Battle engine, matchmaking, leaderboards, daily challenges
```

### AI Memory Integration

Hindsight Memory creates one memory bank per student (`student-{uid}`) and provides three core operations:

| Operation | Usage | Purpose |
|---|---|---|
| **Retain** | After quizzes, topic searches, companion chats | Store learning events with tags |
| **Recall** | Before story generation | Fetch relevant past learning for prompt injection |
| **Reflect** | Level assessment, study pulse, companion answers | AI reasoning over full memory history |

### Navigation Flow

```
Splash → Auth Check → Login (if needed) → Onboarding Check → Home

Home (3-tab bottom nav):
├── Home Tab — Dashboard, Learn Anything, Your Topics, AI Recommends
├── Companion Tab — Study Pulse, Quick Actions, Chat
└── Profile Tab — Stats, Achievements, Battle History
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.11+
- Dart 3.11+
- Firebase CLI
- A connected device or emulator

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd eduju

# Install dependencies
flutter pub get

# Run on a connected device
flutter run
```

### Environment Variables

Pass API keys at build time via `--dart-define`:

```bash
flutter run \
  --dart-define=DEEPSEEK_API_KEY=your_key \
  --dart-define=GROQ_API_KEY=your_key \
  --dart-define=HINDSIGHT_API_KEY=your_key \
  --dart-define=OPENAI_API_KEY=your_key
```

### Build

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Static analysis
flutter analyze
```

### Cloud Functions

```bash
cd functions
npm install
npm run build          # TypeScript compile
npm run serve          # Local emulators
firebase deploy --only functions
```

---

## Firebase Configuration

- **Project:** hire-horizon-c47c7
- **Auth:** Email/Password + Google Sign-In
- **Firestore Collections:** users, battles, challenges, forum_posts, leaderboards, achievements, daily_challenges, matchmaking_queue, learning_paths
- **Cloud Functions:** Node 18, TypeScript
- **Security Rules:** Granular per-collection (see `firestore.rules`)

---

## Documentation

| File | Description |
|---|---|
| `docs/ARCHITECTURE.md` | System architecture and data flow diagrams |
| `docs/DATABASE_SCHEMA.md` | Full Firestore schema with field types |
| `docs/API_PROMPTS.md` | AI prompt templates for challenge generation |

---

## Built With

- [Flutter](https://flutter.dev) — Cross-platform UI framework
- [Firebase](https://firebase.google.com) — Backend-as-a-Service
- [Hindsight Memory](https://vectorize.io) — Persistent AI memory
- [DeepSeek](https://deepseek.com) — Story generation AI
- [Groq](https://groq.com) — Fast inference for sub-topic generation
- [Google Gemini](https://ai.google.dev) — Challenge generation & evaluation
- [Go Router](https://pub.dev/packages/go_router) — Declarative routing
- [Google Fonts](https://pub.dev/packages/google_fonts) — Orbitron + Space Grotesk typography
