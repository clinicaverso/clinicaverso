import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function PageHeader({ eyebrow, title, description, action }: { eyebrow?: string; title: string; description?: string; action?: ReactNode }) {
  return <header className="grid grid-cols-[minmax(0,1fr)_auto] items-end gap-5"><div className="min-w-0">{eyebrow && <p className="mb-2 text-xs font-semibold uppercase text-brand-primary">{eyebrow}</p>}<h1 className="text-3xl font-semibold text-foreground md:text-4xl">{title}</h1>{description && <p className="mt-2 text-base text-muted-foreground">{description}</p>}</div>{action && <div className="shrink-0">{action}</div>}</header>;
}

export function SectionTitle({ children, aside }: { children: ReactNode; aside?: ReactNode }) {
  return <div className="mb-4 flex items-center justify-between gap-4"><h2 className="text-lg font-semibold text-foreground">{children}</h2>{aside}</div>;
}

export function Metric({ label, value, detail, accent = false }: { label: string; value: string; detail?: string; accent?: boolean }) {
  return <div className="border-t border-border pt-4"><p className="text-sm text-muted-foreground">{label}</p><p className={cn("mt-2 text-3xl font-semibold", accent ? "text-product-cards" : "text-foreground")}>{value}</p>{detail && <p className="mt-1 text-xs text-text-muted">{detail}</p>}</div>;
}