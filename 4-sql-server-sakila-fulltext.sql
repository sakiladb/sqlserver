-- film_text populate + full-text search. BUILD-TIME step, run after
-- 2-sql-server-sakila-insert-data.sql (so the film rows exist).
--
-- Parity with the other sakiladb variants: film_text is a populated table, and
-- full-text search works as an *index* underneath it (FULLTEXT INDEX) — it adds
-- no column and does not change the schema sq inspects (still 16 tables +
-- 7 views), exactly like the GIN index on postgres / FULLTEXT on mysql.
-- Verified: CONTAINS((title, description), 'astronaut') returns 78 rows,
-- matching every other variant.
--
-- Query form (the SQL Server analogue of postgres @@ / mysql MATCH...AGAINST):
--   SELECT * FROM film_text WHERE CONTAINS((title, description), 'astronaut');

USE sakila;
GO

INSERT INTO film_text (film_id, title, description)
    SELECT film_id, title, description FROM film;
GO

CREATE FULLTEXT CATALOG sakila_ft AS DEFAULT;
GO

CREATE FULLTEXT INDEX ON film_text(title, description)
    KEY INDEX PK_film_text ON sakila_ft WITH CHANGE_TRACKING AUTO;
GO
