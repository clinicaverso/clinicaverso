import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type { Json } from "@/integrations/supabase/types";

const id = z.string().uuid();
const role = z.enum(["student", "editor", "admin"]);
const cardStatus = z.enum(["draft", "published", "archived"]);
type AdminCardListRow = {
  id: string;
  code: string;
  question: string;
  status: "draft" | "published" | "archived";
  editorial_difficulty: string;
  version: number;
  updated_at: string;
  topic_id: string;
  subtopic_id: string | null;
  topics: { id: string; name: string; area_id: string; areas: { name: string } | null } | null;
  subtopics: { name: string } | null;
  flashcard_sections: Array<{ section_id: string; sections: { name: string } | null }>;
};
const check = async (context: { supabase: any; userId: string }, admin = false) => {
  const { data, error } = await context.supabase.from("user_roles").select("role").eq("user_id", context.userId);
  if (error || !data?.some((row: { role: string }) => admin ? row.role === "admin" : ["admin", "editor"].includes(row.role))) throw new Error("Sem permissão para esta operação.");
};
const fail = (error: { message: string } | null) => { if (error) throw new Error(error.message); };
const cleanSearch = (value: string) => value.replace(/[%,()]/g, " ").trim().slice(0, 120);

export const getAdminOverview = createServerFn({ method: "GET" }).middleware([requireSupabaseAuth]).handler(async ({ context }) => {
  await check(context);
  const db = context.supabase;
  const queries = await Promise.all([
    db.from("flashcards").select("id", { count: "exact", head: true }),
    ...(["published", "draft", "archived"] as const).map(status => db.from("flashcards").select("id", { count: "exact", head: true }).eq("status", status)),
    ...(["areas", "topics", "subtopics"] as const).map(table => db.from(table).select("id", { count: "exact", head: true })),
  ]);
  queries.forEach(result => fail(result.error));
  const date = new Date();
  const fortaleza = new Date(date.toLocaleString("en-US", { timeZone: "America/Fortaleza" }));
  fortaleza.setDate(fortaleza.getDate() - ((fortaleza.getDay() + 6) % 7));
  const week = `${fortaleza.getFullYear()}-${String(fortaleza.getMonth() + 1).padStart(2, "0")}-${String(fortaleza.getDate()).padStart(2, "0")}`;
  const { data: schedules, error } = await db.from("weekly_schedules").select("id, status, section_id, sections(name), weekly_schedule_items(id)").eq("week_start_date", week);
  fail(error);
  return { counts: queries.map(result => result.count ?? 0), week, schedules: schedules ?? [] };
});

export const getTaxonomy = createServerFn({ method: "GET" }).middleware([requireSupabaseAuth]).handler(async ({ context }) => {
  await check(context);
  const [sections, areas, topics, subtopics, tags] = await Promise.all([
    context.supabase.from("sections").select("*").order("name"),
    context.supabase.from("areas").select("*").order("name"),
    context.supabase.from("topics").select("*").order("name"),
    context.supabase.from("subtopics").select("*").order("name"),
    context.supabase.from("tags").select("*").order("name"),
  ]);
  [sections, areas, topics, subtopics, tags].forEach(result => fail(result.error));
  return { sections: sections.data ?? [], areas: areas.data ?? [], topics: topics.data ?? [], subtopics: subtopics.data ?? [], tags: tags.data ?? [] };
});

export const saveTaxonomy = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth])
  .inputValidator((raw) => z.object({ table: z.enum(["sections", "areas", "topics", "subtopics", "tags"]), id: id.optional(), name: z.string().trim().min(1).max(160), slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/), description: z.string().max(2000).default(""), parentId: id.optional(), isActive: z.boolean().default(true) }).parse(raw))
  .handler(async ({ context, data }) => {
    await check(context);
    const payload: Record<string, unknown> = { name: data.name, slug: data.slug, is_active: data.isActive };
    if (data.table !== "tags") payload["description"] = data.description;
    if (data.table === "topics") { if (!data.parentId) throw new Error("Selecione uma área."); payload["area_id"] = data.parentId; }
    if (data.table === "subtopics") { if (!data.parentId) throw new Error("Selecione um tema."); payload["topic_id"] = data.parentId; }
    const query = context.supabase.from(data.table) as any;
    const result = data.id ? await query.update(payload).eq("id", data.id).select("id").single() : await query.insert(payload).select("id").single();
    fail(result.error); return result.data;
  });

const cardInput = z.object({
  id: id.optional(), topicId: id, subtopicId: id.nullable(), sectionIds: z.array(id).min(1), tagIds: z.array(id),
  question: z.string().trim().min(1), shortAnswer: z.string().trim().min(1), comment: z.object({ type: z.literal("doc") }).passthrough(),
  reference: z.string(), difficulty: z.enum(["easy", "medium", "hard"]), status: cardStatus,
});
export const saveCard = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(raw => cardInput.parse(raw))
  .handler(async ({ context, data }) => {
    await check(context);
    const db = context.supabase;
    const fields = { topic_id: data.topicId, subtopic_id: data.subtopicId, question: data.question, short_answer: data.shortAnswer, comment: data.comment as Json, reference: data.reference, editorial_difficulty: data.difficulty, status: data.status, updated_by: context.userId };
    const result = data.id ? await db.from("flashcards").update(fields).eq("id", data.id).select("id,version,code").single() : await db.from("flashcards").insert({ ...fields, created_by: context.userId }).select("id,version,code").single();
    fail(result.error);
    const cardId = result.data?.id;
    if (!cardId) throw new Error("Não foi possível salvar o card.");
    const [sections, tags] = await Promise.all([
      db.from("flashcard_sections").select("section_id").eq("flashcard_id", cardId),
      db.from("flashcard_tags").select("tag_id").eq("flashcard_id", cardId),
    ]);
    fail(sections.error); fail(tags.error);
    const oldSections = (sections.data ?? []).map(x => x.section_id);
    const oldTags = (tags.data ?? []).map(x => x.tag_id);
    const removeSections = oldSections.filter(x => !data.sectionIds.includes(x));
    const removeTags = oldTags.filter(x => !data.tagIds.includes(x));
    if (removeSections.length) fail((await db.from("flashcard_sections").delete().eq("flashcard_id", cardId).in("section_id", removeSections)).error);
    const addSections = data.sectionIds.filter(x => !oldSections.includes(x));
    if (addSections.length) fail((await db.from("flashcard_sections").insert(addSections.map(section_id => ({ flashcard_id: cardId, section_id })))).error);
    if (removeTags.length) fail((await db.from("flashcard_tags").delete().eq("flashcard_id", cardId).in("tag_id", removeTags)).error);
    const addTags = data.tagIds.filter(x => !oldTags.includes(x));
    if (addTags.length) fail((await db.from("flashcard_tags").insert(addTags.map(tag_id => ({ flashcard_id: cardId, tag_id })))).error);
    return { id: cardId, code: result.data?.code ?? "", version: result.data?.version ?? 1 };
  });

export const listCards = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth])
  .inputValidator(raw => z.object({ page: z.number().int().min(1).default(1), search: z.string().default(""), section: z.string().default(""), area: z.string().default(""), topic: z.string().default(""), subtopic: z.string().default(""), status: z.string().default(""), difficulty: z.string().default(""), sort: z.enum(["newest", "oldest", "code", "question"]).default("newest") }).parse(raw))
  .handler(async ({ context, data }) => {
    await check(context);
    const columns = "id,code,question,status,editorial_difficulty,version,updated_at,topic_id,subtopic_id,topics%s(id,name,area_id,areas(name)),subtopics(name),flashcard_sections%s(section_id,sections(name))";
    let query = context.supabase.from("flashcards").select(columns.replace("%s", data.area ? "!inner" : "").replace("%s", data.section ? "!inner" : ""), { count: "exact" });
    if (data.search.trim()) { const search = cleanSearch(data.search); query = query.or(`code.ilike.%${search}%,question.ilike.%${search}%`); }
    if (data.topic) query = query.eq("topic_id", data.topic);
    if (data.subtopic) query = query.eq("subtopic_id", data.subtopic);
    if (data.status) query = query.eq("status", data.status as "draft" | "published" | "archived");
    if (data.difficulty) query = query.eq("editorial_difficulty", data.difficulty);
    if (data.area) query = query.eq("topics.area_id", data.area); // nested relationship filtered below with inner join when needed
    if (data.section) query = query.eq("flashcard_sections.section_id", data.section);
    const sortColumn = data.sort === "code" ? "code" : data.sort === "question" ? "question" : "updated_at";
    const { data: rows, count, error } = await query.order(sortColumn, { ascending: data.sort === "oldest" || data.sort === "code" || data.sort === "question" }).range((data.page - 1) * 25, data.page * 25 - 1);
    fail(error);
    return { rows: (rows ?? []) as unknown as AdminCardListRow[], count: count ?? 0 };
  });

export const getCard = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(raw => z.object({ id }).parse(raw))
  .handler(async ({ context, data }) => {
    await check(context);
    const [card, sections, tags, media] = await Promise.all([
      context.supabase.from("flashcards").select("*").eq("id", data.id).single(),
      context.supabase.from("flashcard_sections").select("section_id").eq("flashcard_id", data.id),
      context.supabase.from("flashcard_tags").select("tag_id").eq("flashcard_id", data.id),
      context.supabase.from("flashcard_media").select("*").eq("flashcard_id", data.id).order("display_order"),
    ]);
    [card, sections, tags, media].forEach(result => fail(result.error));
    const signed = await Promise.all((media.data ?? []).filter(x => x.is_active).map(async item => ({ id: item.id, url: (await context.supabase.storage.from("flashcard-media").createSignedUrl(item.storage_path, 3600)).data?.signedUrl ?? "" })));
    return { card: card.data, sectionIds: (sections.data ?? []).map(x => x.section_id), tagIds: (tags.data ?? []).map(x => x.tag_id), media: (media.data ?? []).map(item => ({ ...item, url: signed.find(x => x.id === item.id)?.url ?? "" })) };
  });

export const duplicateCard = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(raw => z.object({ id }).parse(raw))
  .handler(async ({ context, data }) => {
    await check(context);
    const db = context.supabase;
    const [source, sections, tags, media] = await Promise.all([
      db.from("flashcards").select("*").eq("id", data.id).single(), db.from("flashcard_sections").select("section_id").eq("flashcard_id", data.id), db.from("flashcard_tags").select("tag_id").eq("flashcard_id", data.id), db.from("flashcard_media").select("*").eq("flashcard_id", data.id).eq("is_active", true),
    ]);
    [source, sections, tags, media].forEach(result => fail(result.error));
    const card = source.data;
    if (!card) throw new Error("Card não encontrado.");
    const created = await db.from("flashcards").insert({ topic_id: card.topic_id, subtopic_id: card.subtopic_id, question: card.question, short_answer: card.short_answer, comment: card.comment, reference: card.reference, editorial_difficulty: card.editorial_difficulty, status: "draft", created_by: context.userId, updated_by: context.userId }).select("id,code").single();
    fail(created.error);
    const newId = created.data?.id;
    if (!newId) throw new Error("Falha ao duplicar.");
    if (sections.data?.length) fail((await db.from("flashcard_sections").insert(sections.data.map(x => ({ flashcard_id: newId, section_id: x.section_id })))).error);
    if (tags.data?.length) fail((await db.from("flashcard_tags").insert(tags.data.map(x => ({ flashcard_id: newId, tag_id: x.tag_id })))).error);
    // Copy private files rather than referring two media rows to the same mutable object.
    for (const item of media.data ?? []) {
      const extension = item.storage_path.split(".").pop() ?? "bin";
      const destination = `${newId}/${crypto.randomUUID()}.${extension}`;
      const copied = await db.storage.from("flashcard-media").copy(item.storage_path, destination);
      fail(copied.error);
      fail((await db.from("flashcard_media").insert({ flashcard_id: newId, type: item.type, placement: item.placement, storage_path: destination, caption: item.caption, alt_text: item.alt_text, display_order: item.display_order, created_by: context.userId })).error);
    }
    return { id: newId, code: created.data?.code ?? "" };
  });

export const archiveCard = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(raw => z.object({ id }).parse(raw))
  .handler(async ({ context, data }) => { await check(context); const result = await context.supabase.from("flashcards").update({ status: "archived", updated_by: context.userId }).eq("id", data.id); fail(result.error); return { ok: true }; });

export const saveMedia = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth])
  .inputValidator(raw => z.object({ id: id.optional(), cardId: id, path: z.string().min(1).optional(), type: z.enum(["image", "document"]).optional(), placement: z.enum(["question", "answer", "comment"]), caption: z.string().max(500), altText: z.string().max(500), order: z.number().int().min(0), active: z.boolean() }).parse(raw))
  .handler(async ({ context, data }) => {
    await check(context);
    const fields = { placement: data.placement, caption: data.caption, alt_text: data.altText, display_order: data.order, is_active: data.active };
    const result = data.id ? await context.supabase.from("flashcard_media").update(fields).eq("id", data.id).eq("flashcard_id", data.cardId).select("id").single() : await context.supabase.from("flashcard_media").insert({ ...fields, flashcard_id: data.cardId, storage_path: data.path ?? "", type: data.type ?? "image", created_by: context.userId }).select("id").single();
    fail(result.error); return result.data;
  });

export const listMedia = createServerFn({ method: "GET" }).middleware([requireSupabaseAuth]).handler(async ({ context }) => {
  await check(context);
  const result = await context.supabase.from("flashcard_media").select("*,flashcards(code,question)").order("updated_at", { ascending: false }).limit(100);
  fail(result.error);
  return await Promise.all((result.data ?? []).map(async item => ({ ...item, url: (await context.supabase.storage.from("flashcard-media").createSignedUrl(item.storage_path, 3600)).data?.signedUrl ?? "" })));
});

export const getSchedules = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(raw => z.object({ sectionId: id, from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/), to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/) }).parse(raw))
  .handler(async ({ context, data }) => { await check(context, true); const result = await context.supabase.from("weekly_schedules").select("*,weekly_schedule_items(*,topics(id,name,area_id,areas(name)))").eq("section_id", data.sectionId).gte("week_start_date", data.from).lte("week_start_date", data.to).order("week_start_date"); fail(result.error); return result.data ?? []; });

export const saveSchedule = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(raw => z.object({ id: id.optional(), sectionId: id, week: z.string().regex(/^\d{4}-\d{2}-\d{2}$/), topics: z.array(id).length(3), publish: z.boolean() }).parse(raw))
  .handler(async ({ context, data }) => {
    await check(context, true);
    if (new Date(`${data.week}T12:00:00Z`).getUTCDay() !== 1) throw new Error("A semana deve começar em uma segunda-feira.");
    if (new Set(data.topics).size !== 3) throw new Error("Selecione três temas diferentes.");
    const db = context.supabase;
    let scheduleId = data.id;
    if (scheduleId) {
      const existing = await db.from("weekly_schedules").select("status").eq("id", scheduleId).single(); fail(existing.error);
      if (existing.data?.status !== "draft") throw new Error("Uma programação publicada ou arquivada não pode ser editada.");
      fail((await db.from("weekly_schedule_items").delete().eq("weekly_schedule_id", scheduleId)).error);
    } else {
      const result = await db.from("weekly_schedules").insert({ section_id: data.sectionId, week_start_date: data.week, created_by: context.userId, status: "draft" }).select("id").single(); fail(result.error); scheduleId = result.data?.id;
    }
    if (!scheduleId) throw new Error("Não foi possível criar a programação.");
    const days = [1, 3, 5] as const;
    const rows = data.topics.map((topic_id, index) => ({ weekly_schedule_id: scheduleId, topic_id, release_day: days[index] ?? 1, release_order: index + 1 }));
    // 00:00 in Fortaleza is 03:00 UTC; the existing trigger checks the local release date.
    const items = rows.map((row, index) => ({ ...row, release_at: new Date(Date.parse(`${data.week}T03:00:00Z`) + ((days[index] ?? 1) - 1) * 86400000).toISOString() }));
    fail((await db.from("weekly_schedule_items").insert(items)).error);
    if (data.publish) fail((await db.from("weekly_schedules").update({ status: "published" }).eq("id", scheduleId)).error);
    return { id: scheduleId };
  });

export const archiveSchedule = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(raw => z.object({ id }).parse(raw))
  .handler(async ({ context, data }) => { await check(context, true); const result = await context.supabase.from("weekly_schedules").update({ status: "archived" }).eq("id", data.id); fail(result.error); return { ok: true }; });

export const listUsers = createServerFn({ method: "GET" }).middleware([requireSupabaseAuth]).handler(async ({ context }) => {
  await check(context, true);
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const [users, profiles, roles] = await Promise.all([supabaseAdmin.auth.admin.listUsers({ page: 1, perPage: 1000 }), context.supabase.from("profiles").select("id,display_name,created_at"), context.supabase.from("user_roles").select("user_id,role")]);
  fail(users.error); fail(profiles.error); fail(roles.error);
  return (users.data?.users ?? []).map(user => ({ id: user.id, email: user.email ?? "", createdAt: user.created_at, name: profiles.data?.find(p => p.id === user.id)?.display_name ?? "—", role: roles.data?.find(r => r.user_id === user.id)?.role ?? "student" }));
});

export const setUserRole = createServerFn({ method: "POST" }).middleware([requireSupabaseAuth]).inputValidator(raw => z.object({ userId: id, role }).parse(raw))
  .handler(async ({ context, data }) => {
    await check(context, true);
    if (data.userId === context.userId && data.role !== "admin") throw new Error("Você não pode retirar seu próprio acesso administrativo.");
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const existing = await context.supabase.from("user_roles").select("id,role").eq("user_id", data.userId);
    fail(existing.error);
    const remove = (existing.data ?? []).filter(x => x.role !== data.role);
    if (remove.length) fail((await supabaseAdmin.from("user_roles").delete().in("id", remove.map(x => x.id))).error);
    if (!(existing.data ?? []).some(x => x.role === data.role)) fail((await supabaseAdmin.from("user_roles").insert({ user_id: data.userId, role: data.role })).error);
    return { ok: true };
  });
