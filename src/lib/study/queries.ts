import { queryOptions } from '@tanstack/react-query';
import { readStudy,studyOverview } from './study.functions';
import { dailySummary,readDaily } from './daily.functions';
export const overviewOptions=()=>queryOptions({queryKey:['study','overview'],queryFn:()=>studyOverview(),staleTime:0});
export const sessionOptions=(session:string)=>queryOptions({queryKey:['study','session',session],queryFn:()=>readStudy({data:{session,reveal:false}}),staleTime:0});
export const dailySummaryOptions=(section:string)=>queryOptions({queryKey:['study','daily','summary',section],queryFn:()=>dailySummary({data:{section}}),staleTime:0});
export const dailySessionOptions=(queue:string)=>queryOptions({queryKey:['study','daily','session',queue],queryFn:()=>readDaily({data:{queue,reveal:false}}),staleTime:0});
