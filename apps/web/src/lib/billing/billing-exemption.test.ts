import { describe, expect, it } from "vitest";

import { hasAdminRole } from "./billing-exemption";

describe("hasAdminRole", () => {
	it("returns true for the default Better Auth admin role", () => {
		expect(hasAdminRole("admin")).toBe(true);
	});

	it("returns true when admin is one of multiple comma-separated roles", () => {
		expect(hasAdminRole("user, admin, editor")).toBe(true);
	});

	it("returns false when admin is not present", () => {
		expect(hasAdminRole("user, editor")).toBe(false);
		expect(hasAdminRole(null)).toBe(false);
		expect(hasAdminRole(undefined)).toBe(false);
	});
});
