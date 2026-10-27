import { createServerFn } from '@tanstack/react-start';
import { z } from 'zod';
import { requireSupabaseAuth } from '@/integrations/supabase/auth-middleware';
import { ratingSchema } from './model';
import { computeNext, ratingValue, type FsrsConfigRow, type StoredState } from './fsrs.server';

const uuid = z.string().uuid();

export const dailySummary = createServerFn({ method: 'GET' })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ section: uuid }).parse(raw))
  .handler(async ({ context, data }) => {
    const r = await context.supabase.rpc('daily_summary', { p_section: data.section });
    if (r.error) throw new Error(r.error.message);
    return r.data;
  });

export const startDaily = createServerFn({ method: 'POST' })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ section: uuid }).parse(raw))
  .handler(async ({ context, data }) => {
    const r = await context.supabase.rpc('start_daily_queue', { p_section: data.section });
    if (r.error) throw new Error(r.error.message);
    return r.data as string;
  });

export const readDaily = createServerFn({ method: 'POST' })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ queue: uuid, reveal: z.boolean().default(false) }).parse(raw))
  .handler(async ({ context, data }) => {
    const r = await context.supabase.rpc('read_daily_attempt', { p_queue: data.queue, p_reveal: data.reveal });
    if (r.error) throw new Error(r.error.message);
    const session = r.data as { card?: { media?: Array<{ storage_path: string; url?: string }> } | null };
    if (session.card?.media) {
      session.card.media = await Promise.all(
        session.card.media.map(async (m) => {
          const signed = await context.supabase.storage.from('flashcard-media').createSignedUrl(m.storage_path, 120);
          if (signed.error) throw new Error('Não foi possível carregar a mídia autorizada.');
          return { ...m, url: signed.data.signedUrl };
        }),
      );
    }
    return session;
  });

// Avaliação agendada: prepara no banco, calcula FSRS no servidor, comita via papel privilegiado.
export const rateDaily = createServerFn({ method: 'POST' })
  .middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ attempt: uuid, operation: uuid, rating: ratingSchema }).parse(raw))
  .handler(async ({ context, data }) => {
    const prep = await context.supabase.rpc('prepare_daily_rating', { p_attempt: data.attempt });
    if (prep.error) throw new Error(prep.error.message);
    const receipt = prep.data as {
      committed: boolean; event_id?: string; operation_id?: string; prepared_at?: string;
      config_id?: string; config?: FsrsConfigRow; state?: StoredState;
    };
    if (receipt.committed) return { event_id: receipt.event_id, already: true };
    if (receipt.operation_id !== data.operation) throw new Error('Operação inválida.');
    if (!receipt.config || !receipt.prepared_at || !receipt.config_id) throw new Error('Configuração FSRS ausente.');

    const preparedAt = new Date(receipt.prepared_at);
    const prior = receipt.state ?? null;
    const origin = !prior || prior.review_count === 0
      ? 'new_card'
      : prior.scheduling_status === 'unscheduled'
        ? 'phase4_unscheduled'
        : 'scheduled_review';
    const result = computeNext(receipt.config, prior, ratingValue(data.rating), preparedAt);

    const { supabaseAdmin } = await import('@/integrations/supabase/client.server');
    const commit = await supabaseAdmin.rpc('commit_daily_rating', {
      p_attempt: data.attempt,
      p_operation: data.operation,
      p_rating: data.rating,
      p_result: {
        config_id: receipt.config_id,
        due: result.due,
        scheduled_days: result.scheduled_days,
        state: result.state,
        stability: result.stability,
        difficulty: result.difficulty,
        fsrs_data: result.fsrs_data,
        origin,
      },
    });
    if (commit.error) throw new Error(commit.error.message);
    return { event_id: commit.data as string, already: false, next_review_at: result.due, state: result.state };
  });
