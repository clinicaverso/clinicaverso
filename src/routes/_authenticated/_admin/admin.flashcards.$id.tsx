import { createFileRoute } from "@tanstack/react-router";
import { CardEditor } from "@/components/clinicaverso/card-editor";
import { adminHead } from "@/components/clinicaverso/admin-common";
export const Route = createFileRoute("/_authenticated/_admin/admin/flashcards/$id")({ head: () => adminHead("Editar card", "Edite um card do acervo ClinicaVerso."), component: () => <CardEditor id={Route.useParams().id} /> });
