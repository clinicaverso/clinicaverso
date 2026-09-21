import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowRight, Check, ClipboardList, Clock3, Layers3, Play } from "lucide-react";
import { AppShell } from "@/components/clinicaverso/app-shell";
import { Metric, PageHeader, SectionTitle } from "@/components/clinicaverso/page-parts";
import { Button } from "@/components/ui/button";

export const Route = createFileRoute("/_authenticated/dashboard")({ head: () => ({ meta: [{ title: "Início — ClinicaVerso" }, { name: "description", content: "Sua visão geral de estudos no ClinicaVerso." }, { property: "og:title", content: "Início — ClinicaVerso" }, { property: "og:description", content: "Sua visão geral de estudos no ClinicaVerso." }, { property: "og:type", content: "website" }, { name: "twitter:card", content: "summary_large_image" }] }), component: Dashboard });

const products = [
  { name: "ClinicaVerso Cards", description: "Flashcards para revisão de Clínica Médica.", icon: Layers3, active: true },
  { name: "ClinicaVerso Revisões", description: "Revisões estruturadas para consolidar conteúdos.", icon: ClipboardList, active: false },
  { name: "ClinicaVerso Aulas", description: "Aulas objetivas e direcionadas.", icon: Play, active: false },
];

function Dashboard() {
  return (
    <AppShell>
      <div className="space-y-8 md:space-y-10">
        <PageHeader title="Olá, Nícolas." description="Vamos continuar seus estudos?" />

        <section>
          <SectionTitle>Continuar estudando</SectionTitle>
          <div className="grid gap-5 rounded-lg border border-border bg-surface p-5 transition-colors duration-150 hover:border-border-strong sm:p-6 md:grid-cols-[minmax(0,1fr)_auto] md:items-center">
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase text-product-cards">Clínica Médica · Cardiologia</p>
              <h3 className="mt-2 text-lg font-semibold text-foreground md:text-xl">Síndrome Coronariana Aguda</h3>
              <p className="mt-2 flex items-center gap-2 text-sm text-muted-foreground"><Clock3 className="h-4 w-4 shrink-0" />12 cards pendentes</p>
              <div className="mt-4 h-1 max-w-lg overflow-hidden rounded-full bg-brand-primary-soft" aria-label="38% concluído"><div className="h-full w-[38%] rounded-full bg-brand-primary" /></div>
            </div>
            <Button asChild size="lg" variant="cards" className="w-full sm:w-auto"><Link to="/cards">Continuar revisão <ArrowRight /></Link></Button>
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
                    {product.active ? <><div><p className="flex items-center gap-1.5 text-xs font-medium text-success"><Check className="h-3.5 w-3.5" />Ativo</p><p className="mt-1 text-xs text-muted-foreground">Progresso <span className="font-semibold text-foreground">42%</span></p></div><Button asChild size="sm" variant="cards"><Link to="/cards">Acessar <ArrowRight /></Link></Button></> : <span className="inline-flex rounded-full bg-surface-secondary px-2.5 py-1 text-[11px] font-medium text-muted-foreground">Em breve</span>}
                  </div>
                </article>
              );
            })}
          </div>
        </section>

        <section>
          <SectionTitle>Resumo de estudos</SectionTitle>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4 md:gap-4">
            <Metric label="Cards estudados" value="248" />
            <Metric label="Revisões hoje" value="18" detail="Meta: 24" />
            <Metric label="Sequência" value="7 dias" />
            <Metric label="Progresso R1CM" value="42%" accent progress={42} />
          </div>
        </section>
      </div>
    </AppShell>
  );
}