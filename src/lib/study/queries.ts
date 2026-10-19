import { queryOptions } from '@tanstack/react-query';
import { readStudy,studyOverview } from './study.functions';
export const overviewOptions=()=>queryOptions({queryKey:['study','overview'],queryFn:()=>studyOverview(),staleTime:0});
export const sessionOptions=(session:string)=>queryOptions({queryKey:['study','session',session],queryFn:()=>readStudy({data:{session,reveal:false}}),staleTime:0});
