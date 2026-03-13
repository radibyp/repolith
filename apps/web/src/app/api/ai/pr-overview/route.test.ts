import { beforeEach, describe, expect, it, vi } from "vitest";

const {
	checkUsageLimitMock,
	extractSnippetFromPatchMock,
	generateTextMock,
	getInternalModelMock,
	getPrOverviewAnalysisMock,
	getSessionMock,
	headersMock,
	logTokenUsageMock,
	savePrOverviewAnalysisMock,
	waitUntilMock,
} = vi.hoisted(() => ({
	checkUsageLimitMock: vi.fn(),
	extractSnippetFromPatchMock: vi.fn(),
	generateTextMock: vi.fn(),
	getInternalModelMock: vi.fn(),
	getPrOverviewAnalysisMock: vi.fn(),
	getSessionMock: vi.fn(),
	headersMock: vi.fn(),
	logTokenUsageMock: vi.fn(),
	savePrOverviewAnalysisMock: vi.fn(),
	waitUntilMock: vi.fn(),
}));

vi.mock("ai", () => ({
	Output: {
		object: vi.fn((value: unknown) => value),
	},
	generateText: generateTextMock,
}));

vi.mock("@/lib/auth", () => ({
	auth: {
		api: {
			getSession: getSessionMock,
		},
	},
}));

vi.mock("next/headers", () => ({
	headers: headersMock,
}));

vi.mock("@/lib/billing/ai-models.server", () => ({
	getInternalModel: getInternalModelMock,
}));

vi.mock("@/lib/billing/usage-limit", () => ({
	checkUsageLimit: checkUsageLimitMock,
}));

vi.mock("@/lib/billing/config", () => ({
	getBillingErrorCode: vi.fn(() => "billing_error"),
}));

vi.mock("@/lib/billing/token-usage", () => ({
	logTokenUsage: logTokenUsageMock,
}));

vi.mock("@vercel/functions", () => ({
	waitUntil: waitUntilMock,
}));

vi.mock("@/lib/pr-overview-store", () => ({
	getPrOverviewAnalysis: getPrOverviewAnalysisMock,
	savePrOverviewAnalysis: savePrOverviewAnalysisMock,
}));

vi.mock("@/lib/extract-snippet", () => ({
	extractSnippetFromPatch: extractSnippetFromPatchMock,
}));

describe("POST /api/ai/pr-overview", () => {
	beforeEach(() => {
		vi.resetModules();
		checkUsageLimitMock.mockReset();
		extractSnippetFromPatchMock.mockReset();
		generateTextMock.mockReset();
		getInternalModelMock.mockReset();
		getPrOverviewAnalysisMock.mockReset();
		getSessionMock.mockReset();
		headersMock.mockReset();
		logTokenUsageMock.mockReset();
		savePrOverviewAnalysisMock.mockReset();
		waitUntilMock.mockReset();

		headersMock.mockResolvedValue(new Headers());
		getSessionMock.mockResolvedValue({ user: { id: "user-1" } });
		getInternalModelMock.mockResolvedValue({
			model: { id: "mock-model" },
			modelId: "anthropic/claude-haiku-4.5",
			isCustomApiKey: false,
		});
		checkUsageLimitMock.mockResolvedValue({ allowed: true });
		getPrOverviewAnalysisMock.mockResolvedValue(null);
		savePrOverviewAnalysisMock.mockResolvedValue(null);
		logTokenUsageMock.mockResolvedValue(undefined);
		extractSnippetFromPatchMock.mockReturnValue("const result = true;");
		generateTextMock.mockResolvedValue({
			output: {
				groups: [
					{
						id: "core-review",
						title: "Core Review",
						summary: "Highlights the primary change.",
						reviewOrder: 1,
						files: [
							{
								filename: "src/example.ts",
								explanation:
									"Explains why the file changed.",
								startLine: 10,
								endLine: 16,
							},
						],
					},
				],
			},
			usage: { totalTokens: 321 },
		});
	});

	it("caps PR overview output tokens before calling OpenRouter", async () => {
		const { POST } = await import("./route");

		const response = await POST(
			new Request("http://localhost/api/ai/pr-overview", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify({
					owner: "acme",
					repo: "rocket",
					pullNumber: 42,
					prTitle: "Refine analysis flow",
					prBody: "Keeps the overview concise.",
					files: [
						{
							filename: "src/example.ts",
							status: "modified",
							additions: 12,
							deletions: 4,
							patch: "@@ -1,3 +1,3 @@\n-old\n+new",
						},
					],
				}),
			}),
		);

		expect(response.status).toBe(200);
		expect(generateTextMock).toHaveBeenCalledTimes(1);
		expect(generateTextMock).toHaveBeenCalledWith(
			expect.objectContaining({
				maxOutputTokens: 3000,
				temperature: 0.3,
			}),
		);

		const data = await response.json();
		expect(data).toEqual({
			cached: false,
			groups: [
				{
					id: "core-review",
					reviewOrder: 1,
					summary: "Highlights the primary change.",
					title: "Core Review",
					files: [
						{
							endLine: 16,
							explanation:
								"Explains why the file changed.",
							filename: "src/example.ts",
							snippet: "const result = true;",
							startLine: 10,
						},
					],
				},
			],
		});
	});
});
