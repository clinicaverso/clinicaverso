import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { ArrowRight, Eye, EyeOff } from "lucide-react";
import { Brand } from "@/components/clinicaverso/brand";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/")({
  head: () => ({ meta: [
    { title: "Entrar — ClinicaVerso" },
    { name: "description", content: "Acesse sua plataforma ClinicaVerso de educação médica." },
    { property: "og:title", content: "Entrar — ClinicaVerso" },
    { property: "og:description", content: "Acesse sua plataforma ClinicaVerso de educação médica." },
    { property: "og:type", content: "website" },
    { name: "twitter:card", content: "summary_large_image" },
  ] }),
  component: Index,
});

// IMPORTANT: Replace this placeholder. See ./README.md for routing conventions.
function Index() {
  const navigate = useNavigate({ from: "/" });
  const [showPassword, setShowPassword] = useState(false);
  const [forgot, setForgot] = useState(false);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setMessage("");
    const form = new FormData(event.currentTarget); const email = String(form.get("email") ?? "");
    if (forgot) {
      const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/reset-password` });
      setMessage(error ? "Não foi possível enviar o link. Tente novamente." : "Enviamos as instruções para o seu e-mail."); setBusy(false); return;
    }
    const password = String(form.get("password") ?? "");
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) { setMessage("E-mail ou senha incorretos."); setBusy(false); return; }
    navigate({ to: "/dashboard" });
  }

  return (
    <div className="grid min-h-screen lg:grid-cols-[minmax(0,1fr)_minmax(460px,38%)]">
      <section className="relative hidden overflow-hidden bg-sidebar p-12 lg:flex lg:flex-col lg:justify-between">
        <Brand inverse />
        <div className="max-w-lg"><p className="mb-5 text-xs font-semibold uppercase text-brand-primary">Educação médica, em evolução</p><h1 className="text-5xl font-semibold leading-tight text-sidebar-foreground">Conhecimento que acompanha a sua prática.</h1><p className="mt-6 max-w-md text-base leading-7 text-sidebar-muted">Cards, revisões e aulas organizados em um único ecossistema de aprendizagem.</p></div>
        <p className="text-xs text-sidebar-muted">© 2026 ClinicaVerso</p>
      </section>
      <main className="flex min-h-screen items-center justify-center bg-background px-6 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-12 lg:hidden"><Brand /></div>
          <p className="text-xs font-semibold uppercase text-brand-primary">Área do aluno</p>
          <h2 className="mt-3 text-3xl font-semibold text-foreground">{forgot ? "Recuperar acesso" : "Bem-vindo de volta"}</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">{forgot ? "Informe seu e-mail para receber as instruções." : "Entre para continuar seus estudos."}</p>
          <form className="mt-9 space-y-5" onSubmit={submit}>
            <div className="space-y-2"><Label htmlFor="email">E-mail</Label><Input id="email" name="email" type="email" autoComplete="email" required placeholder="voce@exemplo.com" className="h-12" /></div>
            {!forgot && <div className="space-y-2"><div className="flex items-center justify-between"><Label htmlFor="password">Senha</Label><button type="button" onClick={() => setForgot(true)} className="text-xs font-semibold text-foreground hover:text-brand-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">Esqueci minha senha</button></div><div className="relative"><Input id="password" name="password" type={showPassword ? "text" : "password"} autoComplete="current-password" required className="h-12 pr-12" /><button type="button" onClick={() => setShowPassword((v) => !v)} className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground" aria-label={showPassword ? "Ocultar senha" : "Mostrar senha"}>{showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}</button></div></div>}
            {message && <p role="status" className="text-sm text-muted-foreground">{message}</p>}
            <Button type="submit" size="lg" className="h-12 w-full justify-between" disabled={busy}>{busy ? "Aguarde..." : forgot ? "Enviar instruções" : "Entrar"}<ArrowRight /></Button>
            {forgot && <button type="button" onClick={() => { setForgot(false); setMessage(""); }} className="w-full text-sm font-medium text-muted-foreground hover:text-foreground">Voltar para o login</button>}
          </form>
        </div>
      </main>
    </div>
  );
}
