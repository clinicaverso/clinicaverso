import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { Pencil, Plus } from "lucide-react";
import { saveTaxonomy } from "@/lib/admin.functions";
import { AdminPage, OptionSelect, StateMessage, useTaxonomy } from "./admin-common";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";

type Kind = "sections" | "areas" | "topics" | "subtopics" | "tags";
type Row = { id: string; name: string; slug: string; description?: string; is_active: boolean; area_id?: string; topic_id?: string };
const names: Record<Kind, string> = { sections: "Seções", areas: "Áreas", topics: "Temas", subtopics: "Subtemas", tags: "Tags" };
const slugify = (value: string) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
export function TaxonomyManager({ kind }: { kind: Kind }) {
  const query = useTaxonomy(); const qc = useQueryClient();
  const [item, setItem] = useState<Row | null>(null); const [open, setOpen] = useState(false);
  const [name, setName] = useState(""); const [slug, setSlug] = useState(""); const [description, setDescription] = useState(""); const [parent, setParent] = useState(""); const [active, setActive] = useState(true); const [filter, setFilter] = useState(""); const [status, setStatus] = useState(""); const [saving, setSaving] = useState(false); const [error, setError] = useState("");
  const taxonomy = query.data;
  const rows = (taxonomy?.[kind] ?? []) as Row[];
  const parents = kind === "topics" ? taxonomy?.areas ?? [] : kind === "subtopics" ? taxonomy?.topics ?? [] : [];
  const shown = rows.filter(row => (!filter || (kind === "topics" ? row.area_id : row.topic_id) === filter) && (!status || String(row.is_active) === status));
  const edit = (row?: Row) => { setItem(row ?? null); setName(row?.name ?? ""); setSlug(row?.slug ?? ""); setDescription(row?.description ?? ""); setParent(row?.area_id ?? row?.topic_id ?? ""); setActive(row?.is_active ?? true); setError(""); setOpen(true); };
  const save = async () => { setSaving(true); setError(""); try { await saveTaxonomy({ data: { table: kind, id: item?.id, name, slug, description, parentId: parent || undefined, isActive: active } }); await qc.invalidateQueries({ queryKey: ["admin"] }); setOpen(false); } catch (e) { setError(e instanceof Error ? e.message : "Não foi possível salvar."); } finally { setSaving(false); } };
  return <AdminPage title={names[kind]} description="Organização do acervo ClinicaVerso." action={<Button onClick={() => edit()}><Plus />Novo {names[kind].slice(0,-1).toLowerCase()}</Button>}>
    {(kind === "topics" || kind === "subtopics") && <div className="flex flex-wrap gap-3"><div className="w-56"><OptionSelect value={filter} onChange={setFilter} options={parents} placeholder={kind === "topics" ? "Todas as áreas" : "Todos os temas"} /></div><div className="w-44"><OptionSelect value={status} onChange={setStatus} options={[{ id: "true", name: "Ativo" }, { id: "false", name: "Inativo" }]} placeholder="Todos os status" /></div></div>}
    <div className="overflow-x-auto border-y border-border"><StateMessage loading={query.isLoading} error={query.error} empty={!shown.length}><table className="w-full min-w-[620px] text-left text-sm"><thead className="text-xs text-muted-foreground"><tr><th className="py-3">Nome</th>{parents.length > 0 && <th>{kind === "topics" ? "Área" : "Tema"}</th>}{kind === "topics" && <th>Cards</th>}<th>Status</th><th className="text-right">Ações</th></tr></thead><tbody className="divide-y divide-border">{shown.map(row => <tr key={row.id}><td className="py-4"><p className="font-medium">{row.name}</p><p className="text-xs text-muted-foreground">{row.slug}</p></td>{parents.length > 0 && <td>{parents.find(p => p.id === (row.area_id ?? row.topic_id))?.name ?? "—"}</td>}{kind === "topics" && <td>{(taxonomy?.subtopics ?? []).filter(x => x.topic_id === row.id).length} subtemas</td>}<td className={row.is_active ? "text-success" : "text-muted-foreground"}>{row.is_active ? "Ativo" : "Inativo"}</td><td className="text-right"><Button variant="ghost" size="icon" aria-label={`Editar ${row.name}`} title="Editar" onClick={() => edit(row)}><Pencil /></Button></td></tr>)}</tbody></table></StateMessage></div>
    <Dialog open={open} onOpenChange={setOpen}><DialogContent className="max-w-lg"><DialogHeader><DialogTitle>{item ? "Editar" : "Novo"} {names[kind].toLowerCase()}</DialogTitle></DialogHeader><div className="space-y-4"><div><Label>Nome</Label><Input value={name} onChange={e => { setName(e.target.value); if (!item) setSlug(slugify(e.target.value)); }} /></div><div><Label>Slug</Label><Input value={slug} onChange={e => setSlug(slugify(e.target.value))} /></div>{kind !== "tags" && <div><Label>Descrição</Label><Textarea value={description} onChange={e => setDescription(e.target.value)} /></div>}{parents.length > 0 && <div><Label>{kind === "topics" ? "Área" : "Tema"}</Label><OptionSelect value={parent} onChange={setParent} options={parents} placeholder="Selecione" /></div>}<label className="flex items-center gap-3 text-sm"><input type="checkbox" checked={active} onChange={e => setActive(e.target.checked)} className="accent-primary" />Ativo</label>{error && <p role="alert" className="text-sm text-destructive">{error}</p>}<Button disabled={saving || !name || !slug} onClick={save}>{saving ? "Salvando…" : "Salvar"}</Button></div></DialogContent></Dialog>
  </AdminPage>;
}
