import { z } from 'zod';
import type { Json } from '@/integrations/supabase/types';
const jsonSchema: z.ZodType<Json> = z.lazy(() => z.union([z.string(),z.number(),z.boolean(),z.null(),z.array(jsonSchema),z.record(jsonSchema)]));
export const topicSchema = z.object({id:z.string().uuid(),name:z.string(),area:z.string(),release_at:z.string(),locked:z.boolean().default(false),total:z.number(),studied:z.number()});
export const sessionSchema = z.object({id:z.string().uuid(),total:z.number(),done:z.number(),excluded:z.number(),item_id:z.string().uuid().optional(),revealed:z.boolean().optional(),position:z.number().optional(),card:z.object({id:z.string().uuid(),code:z.string(),version:z.number(),question:z.string(),short_answer:z.string().nullable(),comment:jsonSchema.nullable(),reference:z.string().nullable(),area:z.string().nullable(),topic:z.string().nullable(),subtopic:z.string().nullable(),media:z.array(z.object({type:z.string(),placement:z.string(),storage_path:z.string(),caption:z.string(),alt_text:z.string(),display_order:z.number(),url:z.string().optional()}))}).nullable()});
export type StudySession = z.infer<typeof sessionSchema>;
export const ratingSchema=z.enum(['again','hard','good','easy']);
export const ratings=[{value:'again',label:'Errei'},{value:'hard',label:'Difícil'},{value:'good',label:'Moderado'},{value:'easy',label:'Medular'}] as const;
export function progress(studied:number,total:number){return total>0?Math.round(studied/total*100):0;}
