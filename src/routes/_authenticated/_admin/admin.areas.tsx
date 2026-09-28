import { createFileRoute } from "@tanstack/react-router";
import { TaxonomyManager } from "@/components/clinicaverso/taxonomy-manager";
import { adminHead } from "@/components/clinicaverso/admin-common";
export const Route = createFileRoute("/_authenticated/_admin/admin/areas")({ head: () => adminHead("areas", "Gerencie areas do ClinicaVerso."), component: () => <TaxonomyManager kind="areas" /> });
