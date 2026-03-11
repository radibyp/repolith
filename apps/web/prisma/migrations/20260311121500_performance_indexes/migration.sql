CREATE INDEX "subscription_referenceId_status_idx" ON "subscription"("referenceId", "status");

CREATE INDEX "chat_conversations_userId_updatedAt_idx" ON "chat_conversations"("userId", "updatedAt");

CREATE INDEX "chat_conversations_userId_chatType_updatedAt_idx" ON "chat_conversations"("userId", "chatType", "updatedAt");

CREATE INDEX "pinned_items_userId_owner_repo_pinnedAt_idx" ON "pinned_items"("userId", "owner", "repo", "pinnedAt");

CREATE INDEX "credit_ledger_userId_type_idx" ON "credit_ledger"("userId", "type");

CREATE INDEX "credit_ledger_userId_createdAt_idx" ON "credit_ledger"("userId", "createdAt");

CREATE INDEX "prompt_requests_owner_repo_status_createdAt_idx" ON "prompt_requests"("owner", "repo", "status", "createdAt");
