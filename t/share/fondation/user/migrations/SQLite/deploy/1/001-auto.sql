--
-- Created by SQL::Translator::Producer::SQLite
-- Created on Mon Feb  2 15:55:25 2026
--

;
BEGIN TRANSACTION;

CREATE TABLE "users" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "username" varchar(100) NOT NULL,
  "email" varchar(255) NOT NULL,
  "password" varchar(60) NOT NULL,
  "created_at" datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "active" INTEGER NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX "users_username" ON "users" ("username");
CREATE UNIQUE INDEX "users_email" ON "users" ("email");

COMMIT;
