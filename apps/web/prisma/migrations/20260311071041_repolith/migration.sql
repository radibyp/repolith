-- CreateTable
CREATE TABLE "user" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "githubPat" TEXT,
    "onboardingDone" BOOLEAN NOT NULL DEFAULT false,
    "emailVerified" BOOLEAN NOT NULL,
    "image" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "aiMessageCount" INTEGER NOT NULL DEFAULT 0,
    "lastActiveAt" TIMESTAMP(3),
    "role" TEXT,
    "banned" BOOLEAN DEFAULT false,
    "banReason" TEXT,
    "banExpires" TIMESTAMP(3),
    "stripeCustomerId" TEXT,
    "polarCustomerId" TEXT,

    CONSTRAINT "user_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "session" (
    "id" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "token" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "userId" TEXT NOT NULL,
    "impersonatedBy" TEXT,

    CONSTRAINT "session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "account" (
    "id" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "accessToken" TEXT,
    "refreshToken" TEXT,
    "idToken" TEXT,
    "accessTokenExpiresAt" TIMESTAMP(3),
    "refreshTokenExpiresAt" TIMESTAMP(3),
    "scope" TEXT,
    "password" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "account_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "verification" (
    "id" TEXT NOT NULL,
    "identifier" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3),

    CONSTRAINT "verification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscription" (
    "id" TEXT NOT NULL,
    "plan" TEXT NOT NULL,
    "referenceId" TEXT NOT NULL,
    "stripeCustomerId" TEXT,
    "stripeSubscriptionId" TEXT,
    "status" TEXT DEFAULT 'incomplete',
    "periodStart" TIMESTAMP(3),
    "periodEnd" TIMESTAMP(3),
    "trialStart" TIMESTAMP(3),
    "trialEnd" TIMESTAMP(3),
    "cancelAtPeriodEnd" BOOLEAN DEFAULT false,
    "cancelAt" TIMESTAMP(3),
    "canceledAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),
    "seats" INTEGER,
    "billingInterval" TEXT,
    "stripeScheduleId" TEXT,

    CONSTRAINT "subscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "github_cache_entries" (
    "userId" TEXT NOT NULL,
    "cacheKey" TEXT NOT NULL,
    "cacheType" TEXT NOT NULL,
    "dataJson" TEXT NOT NULL,
    "syncedAt" TEXT NOT NULL,
    "etag" TEXT,

    CONSTRAINT "github_cache_entries_pkey" PRIMARY KEY ("userId","cacheKey")
);

-- CreateTable
CREATE TABLE "github_sync_jobs" (
    "id" SERIAL NOT NULL,
    "userId" TEXT NOT NULL,
    "dedupeKey" TEXT NOT NULL,
    "jobType" TEXT NOT NULL,
    "payloadJson" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "nextAttemptAt" TEXT NOT NULL,
    "startedAt" TEXT,
    "lastError" TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,

    CONSTRAINT "github_sync_jobs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chat_conversations" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "chatType" TEXT NOT NULL,
    "contextKey" TEXT NOT NULL,
    "title" TEXT,
    "activeStreamId" TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,

    CONSTRAINT "chat_conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chat_messages" (
    "id" TEXT NOT NULL,
    "conversationId" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "partsJson" TEXT,
    "createdAt" TEXT NOT NULL,

    CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ghost_tabs" (
    "userId" TEXT NOT NULL,
    "tabId" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "position" INTEGER NOT NULL,

    CONSTRAINT "ghost_tabs_pkey" PRIMARY KEY ("userId","tabId")
);

-- CreateTable
CREATE TABLE "ghost_tab_state" (
    "userId" TEXT NOT NULL,
    "activeTabId" TEXT NOT NULL,
    "counter" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "ghost_tab_state_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "user_settings" (
    "userId" TEXT NOT NULL,
    "displayName" TEXT,
    "theme" TEXT NOT NULL DEFAULT 'system',
    "colorTheme" TEXT NOT NULL DEFAULT 'kalt',
    "colorMode" TEXT NOT NULL DEFAULT 'dark',
    "ghostModel" TEXT NOT NULL DEFAULT 'auto',
    "useOwnApiKey" BOOLEAN NOT NULL DEFAULT false,
    "openrouterApiKey" TEXT,
    "githubPat" TEXT,
    "codeThemeLight" TEXT NOT NULL DEFAULT 'vitesse-light',
    "codeThemeDark" TEXT NOT NULL DEFAULT 'vitesse-black',
    "codeFont" TEXT NOT NULL DEFAULT 'default',
    "codeFontSize" INTEGER NOT NULL DEFAULT 13,
    "onboardingDone" BOOLEAN NOT NULL DEFAULT false,
    "updatedAt" TEXT NOT NULL,

    CONSTRAINT "user_settings_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "custom_code_themes" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "mode" TEXT NOT NULL DEFAULT 'dark',
    "themeJson" TEXT NOT NULL,
    "bgColor" TEXT NOT NULL,
    "fgColor" TEXT NOT NULL,
    "accentColor" TEXT NOT NULL,
    "createdAt" TEXT NOT NULL,

    CONSTRAINT "custom_code_themes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "search_embeddings" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "contentType" TEXT NOT NULL,
    "contentKey" TEXT NOT NULL,
    "owner" TEXT NOT NULL,
    "repo" TEXT NOT NULL,
    "itemNumber" INTEGER NOT NULL,
    "contentHash" TEXT NOT NULL,
    "embeddingJson" TEXT NOT NULL,
    "title" TEXT,
    "snippet" TEXT NOT NULL,
    "metadataJson" TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,

    CONSTRAINT "search_embeddings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pinned_items" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "owner" TEXT NOT NULL,
    "repo" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "itemType" TEXT NOT NULL,
    "pinnedAt" TEXT NOT NULL,

    CONSTRAINT "pinned_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "usage_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "taskType" TEXT NOT NULL,
    "costUsd" DECIMAL(10,6) NOT NULL DEFAULT 0,
    "creditUsed" DECIMAL(10,6) NOT NULL DEFAULT 0,
    "aiCallLogId" INTEGER,
    "stripeReported" BOOLEAN NOT NULL DEFAULT false,
    "polarReported" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "usage_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_call_logs" (
    "id" SERIAL NOT NULL,
    "userId" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "modelId" TEXT NOT NULL,
    "taskType" TEXT NOT NULL,
    "inputTokens" INTEGER NOT NULL DEFAULT 0,
    "outputTokens" INTEGER NOT NULL DEFAULT 0,
    "totalTokens" INTEGER NOT NULL DEFAULT 0,
    "usageJson" TEXT,
    "costJson" TEXT,
    "usingOwnKey" BOOLEAN NOT NULL DEFAULT false,
    "conversationId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_call_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "credit_ledger" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "amount" DECIMAL(10,6) NOT NULL,
    "type" TEXT NOT NULL,
    "description" TEXT,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "credit_ledger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "spending_limit" (
    "userId" TEXT NOT NULL,
    "monthlyCapUsd" DECIMAL(10,2) NOT NULL DEFAULT 10.00,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "spending_limit_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "prompt_requests" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "userLogin" TEXT,
    "userName" TEXT,
    "userAvatarUrl" TEXT,
    "owner" TEXT NOT NULL,
    "repo" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'open',
    "acceptedById" TEXT,
    "acceptedByName" TEXT,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,

    CONSTRAINT "prompt_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "prompt_request_comments" (
    "id" TEXT NOT NULL,
    "promptRequestId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "userLogin" TEXT,
    "userName" TEXT NOT NULL,
    "userAvatarUrl" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,

    CONSTRAINT "prompt_request_comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "prompt_request_reactions" (
    "id" TEXT NOT NULL,
    "promptRequestId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "userLogin" TEXT,
    "userName" TEXT NOT NULL,
    "userAvatarUrl" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "createdAt" TEXT NOT NULL,

    CONSTRAINT "prompt_request_reactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pr_overview_analysis" (
    "id" TEXT NOT NULL,
    "owner" TEXT NOT NULL,
    "repo" TEXT NOT NULL,
    "pullNumber" INTEGER NOT NULL,
    "headSha" TEXT NOT NULL,
    "analysisJson" TEXT NOT NULL,
    "createdAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,

    CONSTRAINT "pr_overview_analysis_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "user_githubPat_email_idx" ON "user"("githubPat", "email");

-- CreateIndex
CREATE UNIQUE INDEX "session_token_key" ON "session"("token");

-- CreateIndex
CREATE INDEX "session_userId_expiresAt_idx" ON "session"("userId", "expiresAt");

-- CreateIndex
CREATE INDEX "account_userId_providerId_idx" ON "account"("userId", "providerId");

-- CreateIndex
CREATE INDEX "verification_identifier_expiresAt_idx" ON "verification"("identifier", "expiresAt");

-- CreateIndex
CREATE INDEX "github_cache_entries_userId_cacheType_idx" ON "github_cache_entries"("userId", "cacheType");

-- CreateIndex
CREATE INDEX "github_sync_jobs_userId_status_nextAttemptAt_id_idx" ON "github_sync_jobs"("userId", "status", "nextAttemptAt", "id");

-- CreateIndex
CREATE UNIQUE INDEX "idx_github_sync_jobs_dedupe_active" ON "github_sync_jobs"("userId", "dedupeKey");

-- CreateIndex
CREATE INDEX "chat_conversations_userId_chatType_idx" ON "chat_conversations"("userId", "chatType");

-- CreateIndex
CREATE UNIQUE INDEX "chat_conversations_userId_contextKey_key" ON "chat_conversations"("userId", "contextKey");

-- CreateIndex
CREATE INDEX "chat_messages_conversationId_createdAt_idx" ON "chat_messages"("conversationId", "createdAt");

-- CreateIndex
CREATE INDEX "search_embeddings_userId_owner_repo_idx" ON "search_embeddings"("userId", "owner", "repo");

-- CreateIndex
CREATE INDEX "search_embeddings_userId_contentType_contentKey_idx" ON "search_embeddings"("userId", "contentType", "contentKey");

-- CreateIndex
CREATE INDEX "pinned_items_userId_owner_repo_idx" ON "pinned_items"("userId", "owner", "repo");

-- CreateIndex
CREATE UNIQUE INDEX "pinned_items_userId_owner_repo_url_key" ON "pinned_items"("userId", "owner", "repo", "url");

-- CreateIndex
CREATE UNIQUE INDEX "usage_logs_aiCallLogId_key" ON "usage_logs"("aiCallLogId");

-- CreateIndex
CREATE INDEX "usage_logs_userId_createdAt_idx" ON "usage_logs"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "usage_logs_stripeReported_createdAt_idx" ON "usage_logs"("stripeReported", "createdAt");

-- CreateIndex
CREATE INDEX "usage_logs_polarReported_createdAt_idx" ON "usage_logs"("polarReported", "createdAt");

-- CreateIndex
CREATE INDEX "ai_call_logs_userId_createdAt_idx" ON "ai_call_logs"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "credit_ledger_userId_expiresAt_idx" ON "credit_ledger"("userId", "expiresAt");

-- CreateIndex
CREATE INDEX "prompt_requests_owner_repo_status_idx" ON "prompt_requests"("owner", "repo", "status");

-- CreateIndex
CREATE INDEX "prompt_requests_userId_idx" ON "prompt_requests"("userId");

-- CreateIndex
CREATE INDEX "prompt_request_comments_promptRequestId_createdAt_idx" ON "prompt_request_comments"("promptRequestId", "createdAt");

-- CreateIndex
CREATE INDEX "prompt_request_comments_userId_idx" ON "prompt_request_comments"("userId");

-- CreateIndex
CREATE INDEX "prompt_request_reactions_promptRequestId_idx" ON "prompt_request_reactions"("promptRequestId");

-- CreateIndex
CREATE INDEX "prompt_request_reactions_userId_idx" ON "prompt_request_reactions"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "prompt_request_reactions_promptRequestId_userId_content_key" ON "prompt_request_reactions"("promptRequestId", "userId", "content");

-- CreateIndex
CREATE INDEX "pr_overview_analysis_owner_repo_pullNumber_headSha_idx" ON "pr_overview_analysis"("owner", "repo", "pullNumber", "headSha");

-- CreateIndex
CREATE UNIQUE INDEX "pr_overview_analysis_owner_repo_pullNumber_key" ON "pr_overview_analysis"("owner", "repo", "pullNumber");

-- AddForeignKey
ALTER TABLE "session" ADD CONSTRAINT "session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "account" ADD CONSTRAINT "account_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "chat_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "usage_logs" ADD CONSTRAINT "usage_logs_aiCallLogId_fkey" FOREIGN KEY ("aiCallLogId") REFERENCES "ai_call_logs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "usage_logs" ADD CONSTRAINT "usage_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_call_logs" ADD CONSTRAINT "ai_call_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "credit_ledger" ADD CONSTRAINT "credit_ledger_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
