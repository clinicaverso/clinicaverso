import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function PageHeader({ eyebrow, title, description, action }: { eyebrow?: string; title: string; description?: string; action?: ReactNode }) {
  return <header className="grid grid-cols-[minmax(0,1fr)_auto] items-end gap-4"><div className="min-w-0">{eyebrow && <p className="mb-2 text-xs font-semibold uppercase text-brand-primary">{eyebrow}</p>}<h1 className="truncate text-2xl font-semibold text-foreground md:text-3xl">{title}</h1>{description && <p className="mt-1.5 text-sm text-muted-foreground md:text-base">{description}</p>}</div>{action && <div className="shrink-0">{action}</div>}</header>;
}

export function SectionTitle({ children, aside }: { children: ReactNode; aside?: ReactNode }) {
  return <div className="mb-3.5 flex items-center justify-between gap-4"><h2 className="text-base font-semibold text-foreground md:text-lg">{children}</h2>{aside}</div>;
}

export function Metric({ label, value, detail, accent = false, progress }: { label: string; value: string; detail?: string; accent?: boolean; progress?: number }) {
  return <div className="rounded-lg border border-border bg-surface p-4 transition-colors duration-150 hover:border-border-strong md:p-5"><p className="text-xs font-medium text-muted-foreground md:text-sm">{label}</p><p className={cn("mt-2 text-2xl font-semibold tracking-normal md:text-3xl", accent ? "text-product-cards" : "text-foreground")}>{value}</p>{detail && <p className="mt-1 text-xs text-text-muted">{detail}</p>}{typeof progress === "number" && <div className="mt-3 h-1 overflow-hidden rounded-full bg-brand-primary-soft" aria-label={`${progress}% concluído`}><div className="h-full rounded-full bg-brand-primary" style={{ width: `${Math.max(0, Math.min(progress, 100))}%` }} /></div>}</div>;
}