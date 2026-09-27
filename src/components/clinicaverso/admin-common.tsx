import { useQuery } from "@tanstack/react-query";
import { getTaxonomy } from "@/lib/admin.functions";
import { AppShell } from "./app-shell";
import { PageHeader } from "./page-parts";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import type { ReactNode } from "react";

export const adminHead = (title: string, description: string) => ({ meta: [{ title: `${title} — Admin ClinicaVerso` }, { name: "description", content: description }, { property: "og:title", content: `${title} — Admin ClinicaVerso` }, { property: "og:description", content: description }, { property: "og:type", content: "website" }, { name: "twitter:card", content: "summary" }] });
export function AdminPage({ title, description, action, children }: { title: string; description?: string; action?: ReactNode; children: ReactNode }) {
  return <AppShell admin><div className="space-y-7"><PageHeader title={title} description={description} action={action} />{children}</div></AppShell>;
}
export function useTaxonomy() { return useQuery({ queryKey: ["admin", "taxonomy"], queryFn: () => getTaxonomy(), staleTime: 60000 }); }
export function OptionSelect({ value, onChange, options, placeholder = "Todos", className }: { value: string; onChange: (value: string) => void; options: { id: string; name: string }[]; placeholder?: string; className?: string }) {
  return <Select value={value || "all"} onValueChange={v => onChange(v === "all" ? "" : v)}><SelectTrigger className={className ?? "h-10 w-full"}><SelectValue placeholder={placeholder} /></SelectTrigger><SelectContent><SelectItem value="all">{placeholder}</SelectItem>{options.map(option => <SelectItem key={option.id} value={option.id}>{option.name}</SelectItem>)}</SelectContent></Select>;
}
export function StateMessage({ loading, error, empty, children }: { loading?: boolean; error?: unknown; empty?: boolean; children: ReactNode }) {
  if (loading) return <p className="py-10 text-sm text-muted-foreground">Carregando…</p>;
  if (error) return <p role="alert" className="py-10 text-sm text-destructive">Não foi possível carregar os dados. Tente novamente.</p>;
  if (empty) return <p className="border-t border-border py-10 text-center text-sm text-muted-foreground">Nenhum resultado encontrado.</p>;
  return <>{children}</>;
}
export function Pager({ page, count, onPage }: { page: number; count: number; onPage: (page: number) => void }) {
  return <div className="flex items-center justify-between border-t border-border py-4 text-sm text-muted-foreground"><span>{count} resultados · Página {page} de {Math.max(1, Math.ceil(count / 25))}</span><div className="flex gap-2"><Button variant="outline" size="sm" disabled={page <= 1} onClick={() => onPage(page - 1)}>Anterior</Button><Button variant="outline" size="sm" disabled={page * 25 >= count} onClick={() => onPage(page + 1)}>Próxima</Button></div></div>;
}
export const formatDate = (value: string) => new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(value));
