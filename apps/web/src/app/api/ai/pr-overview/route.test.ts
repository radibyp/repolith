import { beforeEach, describe, expect, it, vi } from "vitest";

const {
	BILLING_ERROR,
	checkUsageLimitMock,
	extractSnippetFromPatchMock,
	generateTextMock,
	getInternalModelMock,
	getPrOverviewAnalysisMock,
	getSessionMock,
	headersMock,
	isInsufficientCreditBalanceErrorMock,
	logTokenUsageMock,
	savePrOverviewAnalysisMock,
} = vi.hoisted(() => ({
	BILLING_ERROR: {
		CREDIT_EXHAUSTED: "CREDIT_EXHAUSTED",
		MESSAGE_LIMIT_REACHED: "MESSAGE_LIMIT_REACHED",
		SPENDING_LIMIT_REACHED: "SPENDING_LIMIT_REACHED",
	} as const,
	checkUsageLimitMock: vi.fn(),
	extractSnippetFromPatchMock: vi.fn(),
	generateTextMock: vi.fn(),
	getInternalModelMock: vi.fn(),
	getPrOverviewAnalysisMock: vi.fn(),
	getSessionMock: vi.fn(),
	headersMock: vi.fn(),
	isInsufficientCreditBalanceErrorMock: vi.fn(),
	logTokenUsageMock: vi.fn(),
	savePrOverviewAnalysisMock: vi.fn(),
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
	BILLING_ERROR,
	getBillingErrorCode: vi.fn(() => BILLING_ERROR.MESSAGE_LIMIT_REACHED),
}));

vi.mock("@/lib/billing/token-usage", () => ({
	isInsufficientCreditBalanceError: isInsufficientCreditBalanceErrorMock,
	logTokenUsage: logTokenUsageMock,
}));

vi.mock("@/lib/pr-overview-store", () => ({
	getPrOverviewAnalysis: getPrOverviewAnalysisMock,
	savePrOverviewAnalysis: savePrOverviewAnalysisMock,
}));

vi.mock("@/lib/extract-snippet", () => ({
	extractSnippetFromPatch: extractSnippetFromPatchMock,
}));

function buildGeneratedOutput() {
	return {
		groups: [
			{
				id: "core-review",
				title: "Core Review",
				summary: "Highlights the primary change.",
				reviewOrder: 1,
				files: [
					{
						filename: "src/example.ts",
						explanation: "Explains why the file changed.",
						startLine: 10,
						endLine: 16,
					},
				],
			},
		],
	};
}

function buildRequestBody(overrides: Record<string, unknown> = {}) {
	return {
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
		...overrides,
	};
}

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
		isInsufficientCreditBalanceErrorMock.mockReset();
		logTokenUsageMock.mockReset();
		savePrOverviewAnalysisMock.mockReset();

		headersMock.mockResolvedValue(new Headers());
		getSessionMock.mockResolvedValue({ user: { id: "user-1" } });
		getInternalModelMock.mockResolvedValue({
			model: { id: "mock-model" },
			modelId: "anthropic/claude-haiku-4.5",
			isCustomApiKey: false,
		});
		checkUsageLimitMock.mockResolvedValue({ allowed: true });
		getPrOverviewAnalysisMock.mockResolvedValue(null);
		isInsufficientCreditBalanceErrorMock.mockReturnValue(false);
		logTokenUsageMock.mockResolvedValue(undefined);
		savePrOverviewAnalysisMock.mockResolvedValue({
			createdAt: new Date().toISOString(),
			groups: [],
			headSha: "sha-123",
			id: "analysis-1",
			owner: "acme",
			pullNumber: 42,
			repo: "rocket",
			updatedAt: new Date().toISOString(),
		});
		extractSnippetFromPatchMock.mockReturnValue("const result = true;");
		generateTextMock.mockResolvedValue({
			output: buildGeneratedOutput(),
			usage: { totalTokens: 321 },
		});
	});

	it("awaits billing before caching and returning a fresh overview", async () => {
		const callSequence: string[] = [];
		logTokenUsageMock.mockImplementation(async () => {
			callSequence.push("bill");
		});
		savePrOverviewAnalysisMock.mockImplementation(async () => {
			callSequence.push("save");
			return {
				createdAt: new Date().toISOString(),
				groups: [],
				headSha: "sha-123",
				id: "analysis-1",
				owner: "acme",
				pullNumber: 42,
				repo: "rocket",
				updatedAt: new Date().toISOString(),
			};
		});

		const { POST } = await import("./route");
		const response = await POST(
			new Request("http://localhost/api/ai/pr-overview", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify(buildRequestBody({ headSha: "sha-123" })),
			}),
		);

		expect(response.status).toBe(200);
		expect(generateTextMock).toHaveBeenCalledWith(
			expect.objectContaining({
				maxOutputTokens: 3000,
				temperature: 0.3,
			}),
		);
		expect(logTokenUsageMock).toHaveBeenCalledTimes(1);
		expect(savePrOverviewAnalysisMock).toHaveBeenCalledTimes(1);
		expect(callSequence).toEqual(["bill", "save"]);

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
		expect(savePrOverviewAnalysisMock).toHaveBeenCalledWith(
			"acme",
			"rocket",
			42,
			"sha-123",
			data.groups,
		);
	});

	it("returns cached overviews without billing again", async () => {
		getPrOverviewAnalysisMock.mockResolvedValue({
			createdAt: new Date().toISOString(),
			groups: [
				{
					id: "cached-review",
					title: "Cached Review",
					summary: "Already generated.",
					reviewOrder: 1,
					files: [
						{
							filename: "src/example.ts",
							snippet: "+cached",
							explanation: "Uses cached data.",
							startLine: 1,
							endLine: 1,
						},
					],
				},
			],
			headSha: "sha-123",
			id: "analysis-1",
			owner: "acme",
			pullNumber: 42,
			repo: "rocket",
			updatedAt: new Date().toISOString(),
		});

		const { POST } = await import("./route");
		const response = await POST(
			new Request("http://localhost/api/ai/pr-overview", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify(buildRequestBody({ headSha: "sha-123" })),
			}),
		);

		expect(response.status).toBe(200);
		expect(generateTextMock).not.toHaveBeenCalled();
		expect(logTokenUsageMock).not.toHaveBeenCalled();
		expect(savePrOverviewAnalysisMock).not.toHaveBeenCalled();
		expect(await response.json()).toEqual({
			cached: true,
			groups: [
				{
					id: "cached-review",
					title: "Cached Review",
					summary: "Already generated.",
					reviewOrder: 1,
					files: [
						{
							filename: "src/example.ts",
							snippet: "+cached",
							explanation: "Uses cached data.",
							startLine: 1,
							endLine: 1,
						},
					],
				},
			],
		});
	});

	it("returns a billing error when the final debit fails", async () => {
		const balanceError = new Error("Insufficient credit balance to record usage");
		logTokenUsageMock.mockRejectedValueOnce(balanceError);
		isInsufficientCreditBalanceErrorMock.mockImplementation(
			(error: unknown) => error === balanceError,
		);

		const { POST } = await import("./route");
		const response = await POST(
			new Request("http://localhost/api/ai/pr-overview", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify(buildRequestBody({ headSha: "sha-123" })),
			}),
		);

		expect(response.status).toBe(429);
		expect(generateTextMock).toHaveBeenCalledTimes(1);
		expect(logTokenUsageMock).toHaveBeenCalledTimes(1);
		expect(savePrOverviewAnalysisMock).not.toHaveBeenCalled();
		expect(await response.json()).toEqual({
			error: BILLING_ERROR.CREDIT_EXHAUSTED,
			creditExhausted: true,
		});
	});
});
