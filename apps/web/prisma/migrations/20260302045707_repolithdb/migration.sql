-- AlterTable
ALTER TABLE "user" ADD COLUMN     "stripeCustomerId" TEXT;

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
CREATE TABLE "usage_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "taskType" TEXT NOT NULL,
    "costUsd" DECIMAL(10,6) NOT NULL DEFAULT 0,
    "creditUsed" DECIMAL(10,6) NOT NULL DEFAULT 0,
    "aiCallLogId" INTEGER,
    "stripeReported" BOOLEAN NOT NULL DEFAULT false,
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

-- CreateIndex
CREATE UNIQUE INDEX "usage_logs_aiCallLogId_key" ON "usage_logs"("aiCallLogId");

-- CreateIndex
CREATE INDEX "usage_logs_userId_createdAt_idx" ON "usage_logs"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "usage_logs_stripeReported_createdAt_idx" ON "usage_logs"("stripeReported", "createdAt");

-- CreateIndex
CREATE INDEX "ai_call_logs_userId_createdAt_idx" ON "ai_call_logs"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "credit_ledger_userId_expiresAt_idx" ON "credit_ledger"("userId", "expiresAt");

-- AddForeignKey
ALTER TABLE "usage_logs" ADD CONSTRAINT "usage_logs_aiCallLogId_fkey" FOREIGN KEY ("aiCallLogId") REFERENCES "ai_call_logs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "usage_logs" ADD CONSTRAINT "usage_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_call_logs" ADD CONSTRAINT "ai_call_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "credit_ledger" ADD CONSTRAINT "credit_ledger_userId_fkey" FOREIGN KEY ("userId") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
