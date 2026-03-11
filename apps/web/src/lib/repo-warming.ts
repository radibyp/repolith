const DEFAULT_WARM_REPO_LIMIT = 6;

const REPO_SEGMENT_PATTERN = /^[A-Za-z0-9_.-]+$/;

function isValidRepoSegment(segment: string): boolean {
	return REPO_SEGMENT_PATTERN.test(segment);
}

export function isValidRepoFullName(fullName: string): boolean {
	const segments = fullName.split("/");
	return (
		segments.length === 2 &&
		segments.every((segment) => segment.length > 0 && isValidRepoSegment(segment))
	);
}

export function normalizeRepoFullNames(
	repoNames: readonly string[],
	limit = DEFAULT_WARM_REPO_LIMIT,
): string[] {
	const normalized: string[] = [];
	const seen = new Set<string>();

	for (const rawRepoName of repoNames) {
		const repoName = rawRepoName.trim().replace(/^\/+|\/+$/g, "");
		if (!isValidRepoFullName(repoName)) continue;

		const dedupeKey = repoName.toLowerCase();
		if (seen.has(dedupeKey)) continue;

		seen.add(dedupeKey);
		normalized.push(repoName);

		if (normalized.length >= limit) break;
	}

	return normalized;
}

export function repoFullNameFromInternalUrl(url: string): string | null {
	try {
		const pathname = new URL(url, "https://repolith.local").pathname;
		const segments = pathname.split("/").filter(Boolean);

		if (segments.length >= 3 && segments[0] === "repos") {
			const repoName = `${segments[1]}/${segments[2]}`;
			return isValidRepoFullName(repoName) ? repoName : null;
		}

		if (segments.length < 2) return null;

		const repoName = `${segments[0]}/${segments[1]}`;
		return isValidRepoFullName(repoName) ? repoName : null;
	} catch {
		return null;
	}
}

export async function warmReposInBackground(repoNames: readonly string[]): Promise<void> {
	if (typeof window === "undefined") return;

	const repos = normalizeRepoFullNames(repoNames);
	if (repos.length === 0) return;
	const warmReposRoute: string = "/api/performance/warm-repos";

	void fetch(warmReposRoute, {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
		},
		body: JSON.stringify({ repos }),
		cache: "no-store",
		keepalive: true,
	}).catch(() => {});
}
