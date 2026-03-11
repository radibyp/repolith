import { prisma } from "../db";

type UserRoleClient = Pick<typeof prisma, "user">;

export function hasAdminRole(role: string | null | undefined): boolean {
	if (!role) return false;

	return role.split(",").some((value) => value.trim().toLowerCase() === "admin");
}

export async function isBillingExemptUser(
	userId: string,
	client: UserRoleClient = prisma,
): Promise<boolean> {
	const user = await client.user.findUnique({
		where: { id: userId },
		select: { role: true },
	});

	return hasAdminRole(user?.role);
}
