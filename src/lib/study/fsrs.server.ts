// Adaptador FSRS — somente servidor. Nunca importar em código de cliente.
import { fsrs, createEmptyCard, generatorParameters, Rating, State, type Card, type FSRSParameters } from 'ts-fsrs';

export type FsrsConfigRow = {
  id: string;
  request_retention: number;
  maximum_interval: number;
  learning_steps: string[];
  relearning_steps: string[];
  enable_fuzz: boolean;
  enable_short_term: boolean;
  weights: number[];
};

export type StoredState = {
  learning_state: 'new' | 'learning' | 'review' | 'relearning';
  next_review_at: string | null;
  current_interval: number;
  fsrs_stability: number | null;
  fsrs_difficulty: number | null;
  fsrs_data: Record<string, unknown> | null;
  scheduling_status: string | null;
  review_count: number;
} | null;

const STATE_NAMES = ['new', 'learning', 'review', 'relearning'] as const;

export function buildFsrs(cfg: FsrsConfigRow) {
  const params: FSRSParameters = generatorParameters({
    request_retention: Number(cfg.request_retention),
    maximum_interval: cfg.maximum_interval,
    enable_fuzz: cfg.enable_fuzz,
    enable_short_term: cfg.enable_short_term,
    learning_steps: cfg.learning_steps,
    relearning_steps: cfg.relearning_steps,
    w: cfg.weights.map(Number),
  });
  return fsrs(params);
}

// Reconstrói o Card completo a partir do JSON versionado; colunas são apenas projeções.
export function reconstructCard(state: StoredState, now: Date): Card {
  if (!state || !state.fsrs_data || Object.keys(state.fsrs_data).length === 0) {
    return createEmptyCard(now);
  }
  const raw = state.fsrs_data as Record<string, unknown>;
  return {
    due: new Date(raw.due as string),
    stability: Number(raw.stability),
    difficulty: Number(raw.difficulty),
    elapsed_days: Number(raw.elapsed_days),
    scheduled_days: Number(raw.scheduled_days),
    reps: Number(raw.reps),
    lapses: Number(raw.lapses),
    learning_steps: Number(raw.learning_steps ?? 0),
    state: Number(raw.state) as State,
    ...(raw.last_review ? { last_review: new Date(raw.last_review as string) } : {}),
  };
}

export function ratingValue(rating: 'again' | 'hard' | 'good' | 'easy'): Rating {
  return { again: Rating.Again, hard: Rating.Hard, good: Rating.Good, easy: Rating.Easy }[rating];
}

export function computeNext(cfg: FsrsConfigRow, state: StoredState, rating: Rating, now: Date) {
  const engine = buildFsrs(cfg);
  const card = reconstructCard(state, now);
  const result = engine.next(card, now, rating);
  const nextCard = result.card;
  return {
    due: nextCard.due.toISOString(),
    scheduled_days: nextCard.scheduled_days,
    state: STATE_NAMES[nextCard.state],
    stability: nextCard.stability,
    difficulty: nextCard.difficulty,
    fsrs_data: {
      due: nextCard.due.toISOString(),
      stability: nextCard.stability,
      difficulty: nextCard.difficulty,
      elapsed_days: nextCard.elapsed_days,
      scheduled_days: nextCard.scheduled_days,
      reps: nextCard.reps,
      lapses: nextCard.lapses,
      learning_steps: nextCard.learning_steps ?? 0,
      state: nextCard.state,
      ...(nextCard.last_review ? { last_review: nextCard.last_review.toISOString() } : {}),
    },
  };
}
