-- Reference schema for the breeds table the API reads and writes.
-- Your MySQL database on Freehostia already has this table and its data;
-- only run the CREATE if you are setting up a fresh database. The indexes are
-- safe to add to the existing table.
--
-- POST /breeds lets MySQL assign the id, so `id` must be AUTO_INCREMENT. If
-- creating a breed returns 500 server_misconfigured and the PHP error log
-- mentions "Field 'id' doesn't have a default value", run:
--
--   ALTER TABLE breeds MODIFY id INT UNSIGNED NOT NULL AUTO_INCREMENT;
--
-- The live table declares its text columns NOT NULL. The API therefore writes
-- a blank optional field as '' and reads '' back as null, so it works with
-- either definition.
--
-- The API's field limits (breed_name 120, temperament 255, ...) follow the
-- column sizes below. A narrower live column makes long values fail with 422.

CREATE TABLE IF NOT EXISTS breeds (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  breed_name       VARCHAR(120) NOT NULL,
  breed_group      VARCHAR(60)  NULL,
  origin_country   VARCHAR(80)  NULL,
  average_lifespan VARCHAR(40)  NULL,
  temperament      VARCHAR(255) NULL,
  picture          VARCHAR(500) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Speeds up ?group= and ?country= filters and the default name ordering.
CREATE INDEX idx_breeds_group   ON breeds (breed_group);
CREATE INDEX idx_breeds_country ON breeds (origin_country);
CREATE INDEX idx_breeds_name    ON breeds (breed_name);
