import { createFileRoute } from "@tanstack/react-router";
import { CardEditor } from "@/components/clinicaverso/card-editor";
import { adminHead } from "@/components/clinicaverso/admin-common";
export const Route = createFileRoute("/_authenticated/_admin/admin/flashcards/new")({ head: () => adminHead("Novo card", "Crie um card no acervo ClinicaVerso."), component: CardEditor });
