import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowRight, Check, ClipboardList, Clock3, Layers3, Play } from "lucide-react";
import { AppShell } from "@/components/clinicaverso/app-shell";
import { Metric, PageHeader, SectionTitle } from "@/components/clinicaverso/page-parts";
import { Button } from "@/components/ui/button";
import { useSuspenseQuery } from '@tanstack/react-query';
import { overviewOptions, dailySummaryOptions } from '@/lib/study/queries';
import { progress, dailySummarySchema } from '@/lib/study/model';

export const Route = createFileRoute("/_authenticated/dashboard")({ head: () => ({ meta: [{ title: "Início — ClinicaVerso" }, { name: "description", content: "Sua visão geral de estudos no ClinicaVerso." }, { property: "og:title", content: "Início — ClinicaVerso" }, { property: "og:description", content: "Sua visão geral de estudos no ClinicaVerso." }, { property: "og:type", content: "website" }, { name: "twitter:card", content: "summary_large_image" }] }), loader: async ({context})=>{const overview=await context.queryClient.ensureQueryData(overviewOptions());await context.queryClient.ensureQueryData(dailySummaryOptions(overview.section.id));}, component: Dashboard });

const products = [
  { name: "ClinicaVerso Cards", description: "Flashcards para revisão de Clínica Médica.", icon: Layers3, active: true },
  { name: "ClinicaVerso Teoria", description: "Teoria estruturadas para consolidar conteúdos.", icon: ClipboardList, active: false },
  { name: "ClinicaVerso Aulas", description: "Aulas objetivas e direcionadas.", icon: Play, active: false },
];

function Dashboard() {
  const {data}=useSuspenseQuery(overviewOptions());
  const {data:rawDaily}=useSuspenseQuery(dailySummaryOptions(data.section.id));
  const daily=dailySummarySchema.parse(rawDaily);
  const total=data.topics.reduce((n,t)=>n+t.total,0), studied=data.topics.reduce((n,t)=>n+t.studied,0), percent=progress(studied,total);
  const next=data.topics.find(t=>t.id===data.resume?.topicId)??data.topics.find(t=>t.studied<t.total);
  const dueTotal=daily.review_overdue+daily.review_today+daily.learning_due+daily.pending_init;
  return (
    <AppShell>
      <div className="space-y-8 md:space-y-10">
        <PageHeader title={data.name?`Olá, ${data.name.split(' ')[0]}.`:'Olá.'} description="Vamos continuar seus estudos?" />

        <section>
          <SectionTitle>Continuar estudando</SectionTitle>
          <div className="grid gap-5 rounded-lg border border-border bg-surface p-5 transition-colors duration-150 hover:border-border-strong sm:p-6 md:grid-cols-[minmax(0,1fr)_auto] md:items-center">
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase text-product-cards">Clínica Médica{next?` · ${next.area}`:''}</p>
              <h3 className="mt-2 text-lg font-semibold text-foreground md:text-xl">{next?.name??(total?'Temas em dia':'Aguardando novos temas')}</h3>
              <p className="mt-2 flex items-center gap-2 text-sm text-muted-foreground"><Clock3 className="h-4 w-4 shrink-0" />{next?`${next.total-next.studied} cards pendentes`:'Nenhum card novo disponível'}</p>
            </div>
            <Button asChild size="lg" variant="cards" className="w-full sm:w-auto">{data.resume?<Link to="/study/$session" params={{session:data.resume.id}}>Continuar estudo <ArrowRight /></Link>:<Link to="/cards">Ver temas <ArrowRight /></Link>}</Button>
          </div>
        </section>

        <section>
          <SectionTitle>Seus produtos</SectionTitle>
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {products.map((product) => {
              const Icon = product.icon;
              return (
                <article key={product.name} className="flex flex-col rounded-lg border border-border bg-surface p-5 transition-[border-color,transform] duration-150 hover:border-border-strong hover:-translate-y-0.5">
                  <div className="grid grid-cols-[auto_minmax(0,1fr)] items-start gap-3">
                    <div className={product.active ? "grid h-9 w-9 shrink-0 place-items-center rounded-md bg-brand-primary-soft text-brand-primary" : "grid h-9 w-9 shrink-0 place-items-center rounded-md bg-surface-secondary text-muted-foreground"}><Icon className="h-[18px] w-[18px]" /></div>
                    <div className="min-w-0"><h3 className="text-sm font-semibold text-foreground">{product.name}</h3><p className="mt-1 text-xs leading-5 text-muted-foreground">{product.description}</p></div>
                  </div>
                  <div className="mt-5 flex min-h-8 items-center justify-between gap-3 border-t border-border pt-4">
                    {product.active ? <><div><p className="flex items-center gap-1.5 text-xs font-medium text-success"><Check className="h-3.5 w-3.5" />Ativo</p><p className="mt-1 text-xs text-muted-foreground">Progresso <span className="font-semibold text-foreground">{percent}%</span></p></div><Button asChild size="sm" variant="cards"><Link to="/cards">Acessar <ArrowRight /></Link></Button></> : <span className="inline-flex rounded-full bg-surface-secondary px-2.5 py-1 text-[11px] font-medium text-muted-foreground">Em breve</span>}
                  </div>
                </article>
              );
            })}
          </div>
        </section>

        <section>
          <SectionTitle>Resumo de estudos</SectionTitle>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4 md:gap-4">
            <Metric label="Cards estudados" value={String(studied)} />
            <Metric label="Meta diária" value={`${daily.distinct_today} / ${daily.goal}`} detail={daily.distinct_today>=daily.goal?'Meta atingida':'cards distintos'} />
            <Metric label="Revisões pendentes" value={String(dueTotal)} detail={daily.review_overdue>0?`${daily.review_overdue} atrasadas`:undefined} />
            <Metric label="Progresso R1CM" value={`${percent}%`} accent progress={percent} />
          </div>
        </section>
      </div>
    </AppShell>
  );
}