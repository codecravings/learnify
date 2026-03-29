import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// BATTLE FUNCTIONS
// ============================================================================

/**
 * onBattleCreated
 * Triggered when a new battle document is created.
 * Sets a timer to auto-end the battle if participants don't finish in time.
 */
export const onBattleCreated = functions.firestore
  .document("battles/{battleId}")
  .onCreate(async (snap, context) => {
    const battleId = context.params.battleId;
    const battle = snap.data();
    const timeLimitMs = (battle.timeLimitSeconds ?? 120) * 1000;

    functions.logger.info(`Battle ${battleId} created. Auto-end in ${timeLimitMs}ms`);

    // Store the scheduled end time on the battle doc
    await snap.ref.update({
      status: "active",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      scheduledEndAt: admin.firestore.Timestamp.fromMillis(Date.now() + timeLimitMs),
    });

    // Use Cloud Tasks or a delayed check — here we use a Firestore TTL approach
    // by scheduling a callable check. For the hackathon we use a simple delayed write.
    setTimeout(async () => {
      const freshSnap = await db.doc(`battles/${battleId}`).get();
      const freshData = freshSnap.data();
      if (freshData && freshData.status === "active") {
        functions.logger.info(`Auto-ending battle ${battleId} due to timeout`);
        await calculateBattleResultInternal(battleId);
      }
    }, timeLimitMs);
  });

/**
 * onBattleAnswerSubmitted
 * Triggered when a battle document is updated (answer submitted).
 * Checks if both players have answered; if so, calculates the winner.
 */
export const onBattleAnswerSubmitted = functions.firestore
  .document("battles/{battleId}")
  .onUpdate(async (change, context) => {
    const battleId = context.params.battleId;
    const before = change.before.data();
    const after = change.after.data();

    // Only proceed if a new answer was submitted
    if (!after.answers || after.status !== "active") return;

    const playerIds: string[] = after.players ?? [];
    const answers = after.answers ?? {};

    // Check if all players have submitted answers for the current round
    const currentRound: number = after.currentRound ?? 1;
    const allAnswered = playerIds.every(
      (pid: string) => answers[pid] && answers[pid][`round_${currentRound}`] !== undefined
    );

    if (!allAnswered) {
      functions.logger.info(`Battle ${battleId}: waiting for all answers (round ${currentRound})`);
      return;
    }

    functions.logger.info(`Battle ${battleId}: all players answered round ${currentRound}`);

    const totalRounds: number = after.totalRounds ?? 3;

    if (currentRound >= totalRounds) {
      // Final round — calculate overall result
      await calculateBattleResultInternal(battleId);
    } else {
      // Advance to next round
      await change.after.ref.update({
        currentRound: currentRound + 1,
        [`roundResults.round_${currentRound}`]: evaluateRound(after, currentRound),
      });
    }
  });

/**
 * calculateBattleResult (HTTP callable)
 * Can be called manually by clients to force-calculate a battle result.
 */
export const calculateBattleResult = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Login required");

  const battleId = data.battleId;
  if (!battleId) throw new functions.https.HttpsError("invalid-argument", "battleId required");

  return calculateBattleResultInternal(battleId);
});

/**
 * Internal helper: evaluate a single round's answers.
 */
function evaluateRound(battleData: any, round: number): Record<string, any> {
  const players: string[] = battleData.players ?? [];
  const answers = battleData.answers ?? {};
  const challenge = battleData.challenges?.[`round_${round}`];

  const result: Record<string, any> = {};

  for (const pid of players) {
    const playerAnswer = answers[pid]?.[`round_${round}`];
    const isCorrect =
      playerAnswer?.answer?.toString().trim().toLowerCase() ===
      challenge?.correctAnswer?.toString().trim().toLowerCase();
    const timeTaken: number = playerAnswer?.timeTakenMs ?? Infinity;

    result[pid] = {
      correct: isCorrect,
      timeTakenMs: timeTaken,
      score: isCorrect ? Math.max(100, 1000 - Math.floor(timeTaken / 100)) : 0,
    };
  }

  return result;
}

/**
 * Internal helper: calculate final battle result, update scores, award XP.
 */
async function calculateBattleResultInternal(battleId: string) {
  const battleRef = db.doc(`battles/${battleId}`);
  const snap = await battleRef.get();

  if (!snap.exists) throw new Error(`Battle ${battleId} not found`);
  const battle = snap.data()!;

  if (battle.status === "completed") return { alreadyCompleted: true };

  const players: string[] = battle.players ?? [];
  const totalRounds: number = battle.totalRounds ?? 3;
  const scores: Record<string, number> = {};

  // Tally scores across all rounds
  for (const pid of players) {
    scores[pid] = 0;
  }

  for (let r = 1; r <= totalRounds; r++) {
    const roundResult = battle.roundResults?.[`round_${r}`] ?? evaluateRound(battle, r);
    for (const pid of players) {
      scores[pid] += roundResult[pid]?.score ?? 0;
    }
  }

  // Determine winner
  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const winnerId = sorted[0][1] > (sorted[1]?.[1] ?? 0) ? sorted[0][0] : null; // null = draw

  // XP awards
  const xpAwards: Record<string, number> = {};
  for (const pid of players) {
    const isWinner = pid === winnerId;
    const baseXP = isWinner ? 50 : 15;
    const roundBonus = Object.keys(battle.roundResults ?? {}).length * 5;
    xpAwards[pid] = baseXP + roundBonus;
  }

  // Batch update
  const batch = db.batch();

  // Update battle doc
  batch.update(battleRef, {
    status: "completed",
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    finalScores: scores,
    winnerId: winnerId,
    xpAwards: xpAwards,
  });

  // Update each player's profile
  for (const pid of players) {
    const userRef = db.doc(`users/${pid}`);
    batch.update(userRef, {
      xp: admin.firestore.FieldValue.increment(xpAwards[pid]),
      "stats.battlesPlayed": admin.firestore.FieldValue.increment(1),
      ...(pid === winnerId
        ? { "stats.battlesWon": admin.firestore.FieldValue.increment(1) }
        : {}),
      "stats.currentStreak": pid === winnerId
        ? admin.firestore.FieldValue.increment(1)
        : 0,
    });
  }

  await batch.commit();

  functions.logger.info(`Battle ${battleId} completed. Winner: ${winnerId ?? "draw"}`);
  return { winnerId, scores, xpAwards };
}

// ============================================================================
// LEADERBOARD FUNCTIONS
// ============================================================================

/**
 * updateLeaderboards
 * Scheduled to run every hour. Recalculates global and category leaderboards.
 */
export const updateLeaderboards = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async (_context) => {
    functions.logger.info("Recalculating leaderboards...");

    const categories = ["global", "logic", "coding", "reasoning", "cybersecurity", "math"];
    const timeframes = ["daily", "weekly", "allTime"];

    for (const category of categories) {
      for (const timeframe of timeframes) {
        await recalculateLeaderboard(category, timeframe);
      }
    }

    functions.logger.info("Leaderboard recalculation complete.");
  });

async function recalculateLeaderboard(category: string, timeframe: string) {
  let query: admin.firestore.Query = db.collection("users");

  // Apply timeframe filter
  if (timeframe === "daily") {
    const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    // For daily, we rely on xpHistory — simplified for hackathon
  }

  // Get top 100 users by XP (or category-specific XP)
  const xpField = category === "global" ? "xp" : `categoryXP.${category}`;
  const snapshot = await query.orderBy(xpField, "desc").limit(100).get();

  const rankings: any[] = [];
  let rank = 1;

  snapshot.forEach((doc) => {
    const data = doc.data();
    rankings.push({
      rank: rank++,
      userId: doc.id,
      displayName: data.displayName ?? "Anonymous",
      avatarUrl: data.avatarUrl ?? null,
      xp: category === "global" ? data.xp : data.categoryXP?.[category] ?? 0,
      league: data.league ?? "bronze",
      streak: data.stats?.currentStreak ?? 0,
    });
  });

  // Write leaderboard document
  await db.doc(`leaderboards/${category}_${timeframe}`).set({
    category,
    timeframe,
    rankings,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ============================================================================
// DAILY CHALLENGE
// ============================================================================

/**
 * generateDailyChallenge
 * Runs every day at 00:00 UTC. Creates a new daily challenge for all users.
 */
export const generateDailyChallenge = functions.pubsub
  .schedule("every day 00:00")
  .timeZone("UTC")
  .onRun(async (_context) => {
    functions.logger.info("Generating daily challenge...");

    const categories = ["logic", "coding", "reasoning", "cybersecurity", "math"];
    const todayCategory = categories[new Date().getDay() % categories.length];
    const difficulties = ["easy", "medium", "hard"];

    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD

    // Create daily challenge document
    const dailyChallenge = {
      date: today,
      category: todayCategory,
      title: `Daily ${todayCategory.charAt(0).toUpperCase() + todayCategory.slice(1)} Challenge`,
      description: `Today's ${todayCategory} challenge awaits! Solve it to maintain your streak.`,
      difficulty: difficulties[Math.floor(Math.random() * 3)],
      xpReward: 30,
      streakBonusXP: 10,
      startsAt: admin.firestore.Timestamp.fromDate(new Date(`${today}T00:00:00Z`)),
      endsAt: admin.firestore.Timestamp.fromDate(new Date(`${today}T23:59:59Z`)),
      participants: [],
      completions: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      // The actual challenge content would be generated via AI API call
      challenge: {
        type: todayCategory,
        prompt: `[AI-generated ${todayCategory} problem for ${today}]`,
        hints: [
          "Think about the fundamentals.",
          "Break the problem into smaller parts.",
          "Consider edge cases.",
        ],
        correctAnswer: null, // Set by AI evaluation
        timeLimit: 600, // 10 minutes
      },
    };

    await db.doc(`daily_challenges/${today}`).set(dailyChallenge);

    functions.logger.info(`Daily challenge generated: ${todayCategory} for ${today}`);
  });

// ============================================================================
// USER XP & LEAGUE SYSTEM
// ============================================================================

/**
 * onUserXPChanged
 * Triggered when a user document is updated.
 * Checks if XP crossed a league threshold and updates accordingly.
 */
export const onUserXPChanged = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only proceed if XP actually changed
    if (before.xp === after.xp) return;

    const userId = context.params.userId;
    const newXP: number = after.xp ?? 0;

    // League thresholds
    const leagues = [
      { name: "bronze", minXP: 0, icon: "bronze_shield" },
      { name: "silver", minXP: 500, icon: "silver_shield" },
      { name: "gold", minXP: 1500, icon: "gold_shield" },
      { name: "platinum", minXP: 3500, icon: "platinum_shield" },
      { name: "diamond", minXP: 7000, icon: "diamond_shield" },
      { name: "master", minXP: 15000, icon: "master_crown" },
      { name: "grandmaster", minXP: 30000, icon: "grandmaster_crown" },
    ];

    // Find the highest league the user qualifies for
    let newLeague = leagues[0];
    for (const league of leagues) {
      if (newXP >= league.minXP) newLeague = league;
    }

    const oldLeague = before.league ?? "bronze";

    if (newLeague.name !== oldLeague) {
      functions.logger.info(`User ${userId} promoted: ${oldLeague} -> ${newLeague.name}`);

      await change.after.ref.update({
        league: newLeague.name,
        leagueIcon: newLeague.icon,
        leaguePromotedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Check for league-related achievements
      await checkAndAwardAchievements(userId, "league_promotion", {
        newLeague: newLeague.name,
        xp: newXP,
      });
    }

    // Check XP milestone achievements
    const milestones = [100, 500, 1000, 5000, 10000, 25000, 50000];
    for (const milestone of milestones) {
      if (before.xp < milestone && newXP >= milestone) {
        await checkAndAwardAchievements(userId, "xp_milestone", {
          milestone,
          xp: newXP,
        });
      }
    }
  });

/**
 * Internal helper: check conditions and award achievements.
 */
async function checkAndAwardAchievements(
  userId: string,
  triggerType: string,
  data: Record<string, any>
) {
  const achievementDefs: Record<string, any> = {
    league_promotion: [
      { id: "first_promotion", condition: () => true, title: "Moving Up!", xp: 25 },
      {
        id: "gold_league",
        condition: () => data.newLeague === "gold",
        title: "Golden Scholar",
        xp: 50,
      },
      {
        id: "diamond_league",
        condition: () => data.newLeague === "diamond",
        title: "Diamond Mind",
        xp: 100,
      },
      {
        id: "grandmaster",
        condition: () => data.newLeague === "grandmaster",
        title: "Grandmaster",
        xp: 250,
      },
    ],
    xp_milestone: [
      { id: "xp_100", condition: () => data.milestone === 100, title: "Getting Started", xp: 10 },
      { id: "xp_1000", condition: () => data.milestone === 1000, title: "Dedicated Learner", xp: 25 },
      { id: "xp_10000", condition: () => data.milestone === 10000, title: "Knowledge Seeker", xp: 50 },
      { id: "xp_50000", condition: () => data.milestone === 50000, title: "Enlightened", xp: 100 },
    ],
  };

  const relevantAchievements = achievementDefs[triggerType] ?? [];

  for (const achievement of relevantAchievements) {
    if (!achievement.condition()) continue;

    const achievementRef = db.doc(`users/${userId}/achievements/${achievement.id}`);
    const existing = await achievementRef.get();

    if (!existing.exists) {
      await achievementRef.set({
        ...achievement,
        unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
        triggerType,
      });

      // Award bonus XP for the achievement
      await db.doc(`users/${userId}`).update({
        xp: admin.firestore.FieldValue.increment(achievement.xp),
        "stats.achievementsUnlocked": admin.firestore.FieldValue.increment(1),
      });

      functions.logger.info(`Achievement unlocked for ${userId}: ${achievement.title}`);
    }
  }
}

// ============================================================================
// MATCHMAKING
// ============================================================================

/**
 * matchmaking
 * Callable function for real-time battle matchmaking.
 * Finds an opponent with a similar skill rating (+/- tolerance).
 */
export const matchmaking = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const userId = context.auth.uid;
  const category: string = data.category ?? "general";
  const preferredDifficulty: string = data.difficulty ?? "medium";

  // Fetch requesting user's profile
  const userSnap = await db.doc(`users/${userId}`).get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError("not-found", "User profile not found");
  }

  const userData = userSnap.data()!;
  const skillRating: number = userData.skillRating ?? 1000;
  const tolerance = 200; // ELO-style tolerance band

  // Step 1: Check the matchmaking queue for a compatible opponent
  const queueRef = db.collection("matchmaking_queue");
  const compatiblePlayers = await queueRef
    .where("category", "==", category)
    .where("skillRating", ">=", skillRating - tolerance)
    .where("skillRating", "<=", skillRating + tolerance)
    .where("status", "==", "waiting")
    .orderBy("skillRating")
    .orderBy("joinedAt")
    .limit(5)
    .get();

  let opponent: admin.firestore.QueryDocumentSnapshot | null = null;

  compatiblePlayers.forEach((doc) => {
    if (!opponent && doc.id !== userId) {
      opponent = doc;
    }
  });

  if (opponent) {
    // Match found — create a battle
    const opponentData = (opponent as admin.firestore.QueryDocumentSnapshot).data();

    const battleRef = db.collection("battles").doc();
    const battleData = {
      players: [userId, opponent.id],
      playerProfiles: {
        [userId]: {
          displayName: userData.displayName,
          avatarUrl: userData.avatarUrl ?? null,
          skillRating,
          league: userData.league ?? "bronze",
        },
        [opponent.id]: {
          displayName: opponentData.displayName,
          avatarUrl: opponentData.avatarUrl ?? null,
          skillRating: opponentData.skillRating,
          league: opponentData.league ?? "bronze",
        },
      },
      category,
      difficulty: preferredDifficulty,
      status: "created",
      totalRounds: 3,
      currentRound: 1,
      timeLimitSeconds: 120,
      answers: {},
      roundResults: {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const batch = db.batch();
    batch.set(battleRef, battleData);
    // Remove both players from queue
    batch.delete(queueRef.doc(userId));
    batch.delete(queueRef.doc(opponent.id));
    await batch.commit();

    functions.logger.info(`Match found: ${userId} vs ${opponent.id} -> battle ${battleRef.id}`);

    return {
      matched: true,
      battleId: battleRef.id,
      opponent: {
        displayName: opponentData.displayName,
        league: opponentData.league,
        skillRating: opponentData.skillRating,
      },
    };
  } else {
    // No match found — add to queue
    await queueRef.doc(userId).set({
      userId,
      displayName: userData.displayName,
      skillRating,
      category,
      difficulty: preferredDifficulty,
      league: userData.league ?? "bronze",
      status: "waiting",
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`User ${userId} added to matchmaking queue (${category})`);

    return {
      matched: false,
      message: "Added to matchmaking queue. Waiting for opponent...",
      queuePosition: (await queueRef.where("category", "==", category).get()).size,
    };
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// API PROXIES — Solve CORS for web app
// ═══════════════════════════════════════════════════════════════════════════════

function setCors(res: functions.Response) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Max-Age", "3600");
}

/**
 * Proxy for Hindsight Memory API — handles retain, recall, reflect.
 * Flutter web calls this instead of api.hindsight.vectorize.io directly.
 */
export const apiHindsight = functions
  .runWith({ timeoutSeconds: 120, memory: "256MB" })
  .https.onRequest(async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    const API_KEY = process.env.HINDSIGHT_API_KEY || "";
    const targetUrl = `https://api.hindsight.vectorize.io${req.path}`;

    try {
      const fetchOpts: RequestInit = {
        method: req.method,
        headers: {
          "Authorization": `Bearer ${API_KEY}`,
          "Content-Type": "application/json",
        },
      };
      if (req.method !== "GET" && req.body) {
        fetchOpts.body = JSON.stringify(req.body);
      }

      const response = await fetch(targetUrl, fetchOpts);
      const data = await response.json();
      functions.logger.info(`[Hindsight] ${req.method} ${req.path} → ${response.status}`);
      res.status(response.status).json(data);
    } catch (err) {
      functions.logger.error(`[Hindsight] Error: ${err}`);
      res.status(500).json({ error: String(err) });
    }
  });

/**
 * Proxy for DeepSeek AI API — handles story/lesson generation.
 */
export const apiDeepSeek = functions
  .runWith({ timeoutSeconds: 300, memory: "256MB" })
  .https.onRequest(async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    const API_KEY = process.env.DEEPSEEK_API_KEY || "";
    const targetUrl = `https://api.deepseek.com/v1${req.path}`;

    try {
      const response = await fetch(targetUrl, {
        method: req.method,
        headers: {
          "Authorization": `Bearer ${API_KEY}`,
          "Content-Type": "application/json",
        },
        body: req.method !== "GET" ? JSON.stringify(req.body) : undefined,
      });

      const data = await response.json();
      functions.logger.info(`[DeepSeek] ${req.method} ${req.path} → ${response.status}`);
      res.status(response.status).json(data);
    } catch (err) {
      functions.logger.error(`[DeepSeek] Error: ${err}`);
      res.status(500).json({ error: String(err) });
    }
  });

/**
 * Proxy for OpenAI Image API — handles character portrait generation.
 */
export const apiOpenAI = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .https.onRequest(async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    const API_KEY = process.env.OPENAI_API_KEY || "";
    const targetUrl = `https://api.openai.com/v1${req.path}`;

    try {
      const response = await fetch(targetUrl, {
        method: req.method,
        headers: {
          "Authorization": `Bearer ${API_KEY}`,
          "Content-Type": "application/json",
        },
        body: req.method !== "GET" ? JSON.stringify(req.body) : undefined,
      });

      const data = await response.json();
      functions.logger.info(`[OpenAI] ${req.method} ${req.path} → ${response.status}`);
      res.status(response.status).json(data);
    } catch (err) {
      functions.logger.error(`[OpenAI] Error: ${err}`);
      res.status(500).json({ error: String(err) });
    }
  });
