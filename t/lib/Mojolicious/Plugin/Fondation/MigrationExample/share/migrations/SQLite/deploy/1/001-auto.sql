--
-- Created by SQL::Translator::Producer::SQLite
-- Created on Tue Feb  4 16:23:45 2026
--

;
BEGIN TRANSACTION;

CREATE TABLE "example_data" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "name" varchar(255) NOT NULL,
  "value" integer NOT NULL,
  "created_at" datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "description" text
);

COMMIT;