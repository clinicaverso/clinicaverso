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
  MoreHorizontal,
  Users,
  X,
} from "lucide-react";
import { useState, type ReactNode } from "react";
import { Brand } from "./brand";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { supabase } from "@/integrations/supabase/client";
import { useQueryClient } from "@tanstack/react-query";

const studentGroups = [
  { label: "", items: [{ label: "Início", to: "/dashboard", icon: Home }] },
  {
    label: "Produtos",
    items: [
      { label: "Cards", to: "/cards", icon: Layers3 },
      { label: "Revisões", to: "/dashboard", icon: ClipboardList, soon: true },
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
  {
    label: "Administração",
    items: [
      { label: "Dashboard", to: "/admin", icon: Home },
      { label: "Flashcards", to: "/admin/flashcards", icon: Layers3 },
      { label: "Organização", to: "/admin/organization", icon: BookOpen },
      { label: "Usuários", to: "/admin/users", icon: Users },
      { label: "Métricas", to: "/admin/metrics", icon: BarChart3 },
    ],
  },
] as const;

export function AppShell({ children, admin = false }: { children: ReactNode; admin?: boolean }) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const pathname = useRouterState({ select: (state) => state.location.pathname });
  const groups = admin ? adminGroups : studentGroups;

  const sidebar = (
    <div className="flex h-full flex-col">
      <div className="flex h-20 items-center justify-between border-b border-sidebar-border px-5">
        <Brand compact={collapsed} inverse />
        <Button variant="ghostInverse" size="icon" className="hidden lg:inline-flex" onClick={() => setCollapsed((v) => !v)} aria-label={collapsed ? "Expandir menu" : "Recolher menu"}>
          {collapsed ? <ChevronRight /> : <ChevronLeft />}
        </Button>
        <Button variant="ghostInverse" size="icon" className="lg:hidden" onClick={() => setMobileOpen(false)} aria-label="Fechar menu"><X /></Button>
      </div>
      <nav className="flex-1 space-y-7 overflow-y-auto px-3 py-7" aria-label={admin ? "Navegação administrativa" : "Navegação principal"}>
        {groups.map((group) => (
          <div key={group.label || "principal"}>
            {!collapsed && group.label && <p className="mb-2 px-3 text-[11px] font-semibold uppercase text-sidebar-muted">{group.label}</p>}
            <div className="space-y-1">
              {group.items.map((item) => {
                const active = pathname === item.to || (item.to !== "/dashboard" && pathname.startsWith(`${item.to}/`));
                const Icon = item.icon;
                return (
                  <Link key={`${item.label}-${item.to}`} to={item.to} onClick={() => setMobileOpen(false)} className={cn("flex h-11 items-center gap-3 rounded-md px-3 text-sm font-medium text-sidebar-muted transition-colors hover:bg-sidebar-accent hover:text-sidebar-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring", active && "bg-sidebar-accent text-sidebar-foreground")}>
                    <Icon className={cn("h-5 w-5 shrink-0", active && "text-brand-primary")} />
                    {!collapsed && <><span className="min-w-0 truncate">{item.label}</span>{"soon" in item && item.soon && <span className="ml-auto rounded-full border border-sidebar-border px-2 py-0.5 text-[10px] text-sidebar-muted">Em breve</span>}</>}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>
      <div className="border-t border-sidebar-border p-3">
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
      <aside className={cn("fixed inset-y-0 left-0 z-40 hidden bg-sidebar transition-[width] duration-200 lg:block", collapsed ? "w-[72px]" : "w-[252px]")}>{sidebar}</aside>
      {mobileOpen && <><button type="button" aria-label="Fechar navegação" className="fixed inset-0 z-40 bg-overlay lg:hidden" onClick={() => setMobileOpen(false)} /><aside className="fixed inset-y-0 left-0 z-50 w-[286px] bg-sidebar lg:hidden">{sidebar}</aside></>}
      <div className={cn("transition-[margin] duration-200", collapsed ? "lg:ml-[72px]" : "lg:ml-[252px]")}>
        <header className="sticky top-0 z-30 flex h-16 items-center border-b border-border bg-background/95 px-5 backdrop-blur md:px-8 lg:hidden">
          <Button variant="ghost" size="icon" onClick={() => setMobileOpen(true)} aria-label="Abrir menu"><Menu /></Button>
          <div className="ml-3"><Brand /></div>
        </header>
        <main className="mx-auto w-full max-w-[1440px] px-5 py-8 md:px-10 md:py-12 lg:px-14">{children}</main>
      </div>
    </div>
  );
}