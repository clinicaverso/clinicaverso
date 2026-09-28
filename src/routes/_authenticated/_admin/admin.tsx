import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Plus } from "lucide-react";
import { getAdminOverview } from "@/lib/admin.functions";
import { AdminPage, StateMessage, adminHead } from "@/components/clinicaverso/admin-common";
import { Metric, SectionTitle } from "@/components/clinicaverso/page-parts";
import { Button } from "@/components/ui/button";
export const Route = createFileRoute("/_authenticated/_admin/admin")({ head: () => adminHead("Dashboard", "Visão geral do acervo e da programação ClinicaVerso."), component: Dashboard });
function Dashboard() {
  const query = useQuery({ queryKey: ["admin", "overview"], queryFn: () => getAdminOverview() });
  const d = query.data;
  return <AdminPage title="Dashboard" description="Visão geral do conteúdo." action={<Button asChild><Link to="/admin/flashcards/new"><Plus />Novo card</Link></Button>}><StateMessage loading={query.isLoading} error={query.error}><div className="space-y-9"><section><SectionTitle>Cards</SectionTitle><div className="grid grid-cols-2 gap-4 lg:grid-cols-4">{["Total", "Publicados", "Rascunhos", "Arquivados"].map((label, i) => <Metric key={label} label={label} value={String(d?.counts[i] ?? 0)} />)}</div></section><section className="border-t border-border pt-6"><SectionTitle>Taxonomia</SectionTitle><div className="grid grid-cols-2 gap-4 lg:grid-cols-3">{["Áreas", "Temas", "Subtemas"].map((label, i) => <Metric key={label} label={label} value={String(d?.counts[i + 4] ?? 0)} />)}</div></section><section className="border-t border-border pt-6"><SectionTitle>Semana atual · {d?.week}</SectionTitle><div className="divide-y divide-border">{d?.schedules.length ? d.schedules.map(s => <p key={s.id} className="flex justify-between py-3 text-sm"><span>{s.sections?.name}</span><span className="text-muted-foreground">{s.weekly_schedule_items.length} temas · {s.status}</span></p>) : <p className="py-5 text-sm text-muted-foreground">Nenhuma programação nesta semana.</p>}</div></section><div className="flex flex-wrap gap-3"><Button variant="outline" asChild><Link to="/admin/topics"><Plus />Novo tema</Link></Button><Button variant="outline" asChild><Link to="/admin/schedule"><Plus />Programar semana</Link></Button></div></div></StateMessage></AdminPage>;
}
