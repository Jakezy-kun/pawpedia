-- Reference schema for the breeds table the API reads.
-- Your MySQL database on Freehostia already has this table and its data;
-- only run the CREATE if you are setting up a fresh database. The indexes are
-- safe to add to the existing table.

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
