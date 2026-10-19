import { createServerFn } from '@tanstack/react-start';
import { z } from 'zod';
import { requireSupabaseAuth } from '@/integrations/supabase/auth-middleware';
import { sessionSchema,topicSchema,ratingSchema } from './model';
const uuid=z.string().uuid();
export const studyOverview=createServerFn({method:'GET'}).middleware([requireSupabaseAuth]).handler(async({context})=>{
 const db=context.supabase;
 const section=await db.from('sections').select('id,name').eq('slug','r1cm').eq('is_active',true).single();
 if(section.error)throw new Error('Seção indisponível.');
 const catalog=await db.rpc('study_catalog',{p_section:section.data.id});if(catalog.error)throw new Error(catalog.error.message);
 const topics=z.array(topicSchema).parse(catalog.data);
 const date=new Date();const day=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Fortaleza',year:'numeric',month:'2-digit',day:'2-digit'}).format(date);
 const [today,prefs,sessions,profile]=await Promise.all([
 db.from('learning_events').select('id',{count:'exact',head:true}).eq('user_id',context.userId).gte('reviewed_at',`${day}T00:00:00-03:00`).lt('reviewed_at',new Date(new Date(`${day}T00:00:00-03:00`).getTime()+86400000).toISOString()),
 db.from('user_study_preferences').select('daily_card_goal').eq('user_id',context.userId).maybeSingle(),
 db.from('study_sessions').select('id,topic_id,study_session_items(event_id,skipped)').eq('user_id',context.userId).eq('section_id',section.data.id).order('updated_at',{ascending:false}).limit(50),
 db.from('profiles').select('display_name').eq('id',context.userId).maybeSingle()]);
 for(const r of [today,prefs,sessions,profile])if(r.error)throw new Error(r.error.message);
 const pending=sessions.data?.find(s=>topics.some(t=>t.id===s.topic_id&&t.studied<t.total)&&s.study_session_items.some(i=>!i.event_id&&!i.skipped));
 return {section:section.data,topics,today:today.count??0,goal:prefs.data?.daily_card_goal??25,name:profile.data?.display_name??'',resume:pending?{id:pending.id,topicId:pending.topic_id}:null};
});
export const beginStudy=createServerFn({method:'POST'}).middleware([requireSupabaseAuth]).inputValidator(raw=>z.object({section:uuid,topic:uuid}).parse(raw)).handler(async({context,data})=>{const r=await context.supabase.rpc('start_study_session',{p_section:data.section,p_topic:data.topic});if(r.error)throw new Error(r.error.message);return r.data;});
export const readStudy=createServerFn({method:'POST'}).middleware([requireSupabaseAuth]).inputValidator(raw=>z.object({session:uuid,reveal:z.boolean().default(false)}).parse(raw)).handler(async({context,data})=>{
 const r=await context.supabase.rpc('read_study_session',{p_session:data.session,p_reveal:data.reveal});if(r.error)throw new Error(r.error.message);
 const session=sessionSchema.parse(r.data);
 if(session.card)session.card.media=await Promise.all(session.card.media.map(async m=>{const signed=await context.supabase.storage.from('flashcard-media').createSignedUrl(m.storage_path,120);if(signed.error)throw new Error('Não foi possível carregar a mídia autorizada.');return {...m,url:signed.data.signedUrl};}));
 return session;
});
export const rateStudy=createServerFn({method:'POST'}).middleware([requireSupabaseAuth]).inputValidator(raw=>z.object({session:uuid,operation:uuid,rating:ratingSchema}).parse(raw)).handler(async({context,data})=>{const r=await context.supabase.rpc('rate_study_item',{p_session:data.session,p_operation:data.operation,p_rating:data.rating});if(r.error)throw new Error(r.error.message);return r.data;});
