import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import {
  BarChart3,
  BookOpen,
  ChevronLeft,
  ChevronRight,
  CircleUserRound,
  ClipboardList,
  GraduationCap,
  Home,
  Layers3,
  LogOut,
  Menu,
  Image, Tags, CalendarDays, Grid2X2, ListTree, FolderTree, MoreHorizontal, FileSpreadsheet,
  Users,
  X,
} from "lucide-react";
import { useState, type ReactNode } from "react";
import { Brand } from "./brand";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { cn } from "@/lib/utils";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { getMyAccess } from "@/lib/auth.functions";

const studentGroups = [
  { label: "", items: [{ label: "Início", to: "/dashboard", icon: Home }] },
  {
    label: "Produtos",
    items: [
      { label: "Cards", to: "/cards", icon: Layers3 },
      { label: "Teoria", to: "/dashboard", icon: ClipboardList, soon: true },
      { label: "Aulas", to: "/dashboard", icon: GraduationCap, soon: true },
    ],
  },
  {
    label: "Outros",
    items: [
      { label: "Desempenho", to: "/performance", icon: BarChart3 },
      { label: "Perfil", to: "/profile", icon: CircleUserRound },
    ],
  },
] as const;

const adminGroups = [
  { label: "Visão geral", items: [{ label: "Dashboard", to: "/admin", icon: Home, adminOnly: true }] },
  { label: "Conteúdo", items: [
    { label: "Cards", to: "/admin/flashcards", icon: Layers3 },
    { label: "Importar cards", to: "/admin/import", icon: FileSpreadsheet },
    { label: "Seções", to: "/admin/sections", icon: Grid2X2 },
    { label: "Áreas", to: "/admin/areas", icon: BookOpen },
    { label: "Temas", to: "/admin/topics", icon: FolderTree },
    { label: "Subtemas", to: "/admin/subtopics", icon: ListTree },
    { label: "Tags", to: "/admin/tags", icon: Tags },
    { label: "Mídia", to: "/admin/media", icon: Image },
  ] },
  { label: "Currículo", items: [{ label: "Programação semanal", to: "/admin/schedule", icon: CalendarDays, adminOnly: true }] },
  { label: "Gestão", items: [{ label: "Usuários", to: "/admin/users", icon: Users, adminOnly: true }] },
] as const;

export function AppShell({ children, admin = false }: { children: ReactNode; admin?: boolean }) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const { data: access } = useQuery({ queryKey: ["my-access"], queryFn: () => getMyAccess(), enabled: admin });
  const groups = admin ? adminGroups : studentGroups;

  const sidebar = (
    <div className="flex h-full flex-col">
      <div className="flex h-[68px] items-center justify-between border-b border-sidebar-border px-4">
        <Brand compact={collapsed} inverse />
        <Button variant="ghostInverse" size="icon" className="hidden lg:inline-flex" onClick={() => setCollapsed((v) => !v)} aria-label={collapsed ? "Expandir menu" : "Recolher menu"}>
          {collapsed ? <ChevronRight /> : <ChevronLeft />}
        </Button>
        <Button variant="ghostInverse" size="icon" className="lg:hidden" onClick={() => setMobileOpen(false)} aria-label="Fechar menu"><X /></Button>
      </div>
      {!admin && (
        <div className="border-b border-sidebar-border px-2.5 py-3">
          {collapsed ? (
            <div className="grid h-10 place-items-center rounded-md border border-sidebar-border bg-sidebar-accent text-[11px] font-bold text-brand-primary" title="Seção atual: R1CM">R1</div>
          ) : (
            <div>
              <label className="mb-1.5 block px-1 text-[10px] font-semibold uppercase text-sidebar-muted">Seção</label>
              <Select defaultValue="r1cm">
                <SelectTrigger className="h-10 border-sidebar-border bg-sidebar-accent px-3 text-sidebar-foreground shadow-none focus:ring-sidebar-ring" aria-label="Selecionar seção">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="r1cm">R1CM</SelectItem>
                  <SelectItem value="rmaiscm" disabled><span className="flex w-full items-center gap-3"><span>R+CM</span><span className="ml-auto rounded-full border border-border px-1.5 py-0.5 text-[9px] font-medium text-muted-foreground">Em breve</span></span></SelectItem>
                  <SelectItem value="tecm" disabled><span className="flex w-full items-center gap-3"><span>TECM</span><span className="ml-auto rounded-full border border-border px-1.5 py-0.5 text-[9px] font-medium text-muted-foreground">Em breve</span></span></SelectItem>
                </SelectContent>
              </Select>
            </div>
          )}
        </div>
      )}
      <nav className="flex-1 space-y-6 overflow-y-auto px-2.5 py-6" aria-label={admin ? "Navegação administrativa" : "Navegação principal"}>
        {groups.map((group) => (
          <div key={group.label || "principal"}>
            {!collapsed && group.label && <p className="mb-2 px-2.5 text-[10px] font-semibold uppercase text-sidebar-muted">{group.label}</p>}
            <div className="space-y-1">
              {group.items.filter(item => !("adminOnly" in item && item.adminOnly) || access?.roles.includes("admin")).map((item) => {
                const active = !("soon" in item && item.soon) && (pathname === item.to || (item.to !== "/dashboard" && pathname.startsWith(`${item.to}/`)));
                const Icon = item.icon;
                const itemClassName = cn("flex h-10 items-center gap-3 rounded-md px-2.5 text-[13px] font-medium text-sidebar-muted transition-[color,background-color] duration-150 hover:bg-sidebar-accent hover:text-sidebar-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring", active && "bg-sidebar-accent text-sidebar-foreground");
                const content = <><Icon className={cn("h-[18px] w-[18px] shrink-0", active && "text-brand-primary")} />{!collapsed && <><span className="min-w-0 truncate">{item.label}</span>{"soon" in item && item.soon && <span className="ml-auto rounded-full border border-sidebar-border px-1.5 py-0.5 text-[9px] font-medium text-sidebar-muted">Em breve</span>}</>}</>;
                if ("soon" in item && item.soon) return <div key={`${item.label}-${item.to}`} className={cn(itemClassName, "cursor-default hover:bg-transparent hover:text-sidebar-muted")}>{content}</div>;
                return (
                  <Link key={`${item.label}-${item.to}`} to={item.to} onClick={() => setMobileOpen(false)} className={itemClassName}>{content}</Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>
      <div className="border-t border-sidebar-border p-2.5">
        <div className="flex items-center gap-3 rounded-md p-2">
          <div className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-brand-primary text-xs font-bold text-brand-primary-foreground">NR</div>
          {!collapsed && <div className="min-w-0 flex-1"><p className="truncate text-sm font-semibold text-sidebar-foreground">Nícolas</p><p className="text-xs text-sidebar-muted">{admin ? "Administrador" : "Aluno"}</p></div>}
          {!collapsed && <Button variant="ghostInverse" size="icon" aria-label="Sair" title="Sair" onClick={async () => { await queryClient.cancelQueries(); queryClient.clear(); await supabase.auth.signOut(); navigate({ to: "/", replace: true }); }}><LogOut /></Button>}
        </div>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-background">
       <aside className={cn("fixed inset-y-0 left-0 z-40 hidden bg-sidebar transition-[width] duration-200 lg:block", collapsed ? "w-[68px]" : "w-[232px]")}>{sidebar}</aside>
      {mobileOpen && <><button type="button" aria-label="Fechar navegação" className="fixed inset-0 z-40 bg-overlay lg:hidden" onClick={() => setMobileOpen(false)} /><aside className="fixed inset-y-0 left-0 z-50 w-[286px] bg-sidebar lg:hidden">{sidebar}</aside></>}
      <div className={cn("transition-[margin] duration-200", collapsed ? "lg:ml-[68px]" : "lg:ml-[232px]")}> 
        <header className="sticky top-0 z-30 grid h-14 grid-cols-[auto_minmax(0,1fr)] items-center border-b border-border bg-background/95 px-4 backdrop-blur md:px-6 lg:hidden">
          <Button variant="ghost" size="icon" onClick={() => setMobileOpen(true)} aria-label="Abrir menu"><Menu /></Button>
          <div className="ml-2 min-w-0"><Brand /></div>
        </header>
        <main className="mx-auto w-full max-w-[1280px] px-4 py-6 sm:px-6 md:px-8 md:py-8 lg:px-10 lg:py-10">{children}</main>
      </div>
    </div>
  );
}