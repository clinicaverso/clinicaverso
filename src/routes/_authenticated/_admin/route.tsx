import { createFileRoute, Outlet, redirect } from "@tanstack/react-router";
import { getMyAccess } from "@/lib/auth.functions";

export const Route = createFileRoute("/_authenticated/_admin")({
  beforeLoad: async ({ location }) => {
    const access = await getMyAccess();
    if (!access.roles.includes("admin") && !access.roles.includes("editor")) throw redirect({ to: "/dashboard" });
    if (!access.roles.includes("admin") && (/^\/admin(\/users|\/schedule|\/metrics)?$/.test(location.pathname))) throw redirect({ to: "/admin/flashcards" });
    return access;
  },
  component: () => <Outlet />,
});