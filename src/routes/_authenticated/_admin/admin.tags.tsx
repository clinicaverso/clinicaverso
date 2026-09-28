import { createFileRoute } from "@tanstack/react-router";
import { TaxonomyManager } from "@/components/clinicaverso/taxonomy-manager";
import { adminHead } from "@/components/clinicaverso/admin-common";
export const Route = createFileRoute("/_authenticated/_admin/admin/tags")({ head: () => adminHead("tags", "Gerencie tags do ClinicaVerso."), component: () => <TaxonomyManager kind="tags" /> });
