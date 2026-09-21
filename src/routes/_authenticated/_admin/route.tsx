import { createFileRoute, Outlet, redirect } from "@tanstack/react-router";
import { getMyAccess } from "@/lib/auth.functions";

export const Route = createFileRoute("/_authenticated/_admin")({
  beforeLoad: async () => {
    const access = await getMyAccess();
    if (!access.roles.includes("admin")) throw redirect({ to: "/dashboard" });
    return access;
  },
  component: () => <Outlet />,
});