-- CreateTable
CREATE TABLE "theme_store_extensions" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "owner" TEXT NOT NULL,
    "repo" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "version" TEXT NOT NULL DEFAULT '1.0.0',
    "manifestJson" TEXT NOT NULL,
    "dataJson" TEXT,
    "readmeHtml" TEXT,
    "iconUrl" TEXT,
    "license" TEXT,
    "authorGithubId" TEXT NOT NULL,
    "authorName" TEXT NOT NULL,
    "authorAvatarUrl" TEXT,
    "downloads" INTEGER NOT NULL DEFAULT 0,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "featured" BOOLEAN NOT NULL DEFAULT false,
    "publishedAt" TEXT NOT NULL,
    "updatedAt" TEXT NOT NULL,
    "dataCachedAt" TEXT,

    CONSTRAINT "theme_store_extensions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_theme_store_installs" (
    "userId" TEXT NOT NULL,
    "extensionId" TEXT NOT NULL,
    "installedAt" TEXT NOT NULL,

    CONSTRAINT "user_theme_store_installs_pkey" PRIMARY KEY ("userId","extensionId")
);

-- CreateIndex
CREATE UNIQUE INDEX "theme_store_extensions_slug_key" ON "theme_store_extensions"("slug");

-- CreateIndex
CREATE INDEX "theme_store_extensions_type_idx" ON "theme_store_extensions"("type");

-- CreateIndex
CREATE INDEX "theme_store_extensions_downloads_idx" ON "theme_store_extensions"("downloads");

-- CreateIndex
CREATE UNIQUE INDEX "theme_store_extensions_owner_repo_key" ON "theme_store_extensions"("owner", "repo");

-- CreateIndex
CREATE INDEX "user_theme_store_installs_userId_idx" ON "user_theme_store_installs"("userId");

-- AddForeignKey
ALTER TABLE "user_theme_store_installs" ADD CONSTRAINT "user_theme_store_installs_extensionId_fkey" FOREIGN KEY ("extensionId") REFERENCES "theme_store_extensions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
