import { createFileRoute } from "@tanstack/react-router";
import { TaxonomyManager } from "@/components/clinicaverso/taxonomy-manager";
import { adminHead } from "@/components/clinicaverso/admin-common";
export const Route = createFileRoute("/_authenticated/_admin/admin/topics")({ head: () => adminHead("topics", "Gerencie topics do ClinicaVerso."), component: () => <TaxonomyManager kind="topics" /> });
