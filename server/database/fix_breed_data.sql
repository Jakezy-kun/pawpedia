-- ============================================================================
--  PawPedia — two fixes for the live `dogbreeds` table
-- ============================================================================
--
--  1. PHOTOS. Every row's `picture` points at https://via.placeholder.com, a
--     service that has shut down. The domain no longer resolves, so no app or
--     browser can load those images. Replaced below with free photos from
--     dog.ceo (the Stanford Dogs dataset), which allows hotlinking — nothing
--     to download or upload. Every URL here was requested and returned a real
--     JPEG before this file was written.
--
--  2. TYPO. Row 9 is named "DChihuahua". Corrected to "Chihuahua".
--
--  HOW TO RUN
--    1. Freehostia -> phpMyAdmin.
--    2. Pick your database on the left (ferman100_ferman100).
--    3. Click the "SQL" tab at the top.
--    4. Paste this whole file, then press "Go".
--
--  SAFETY: only the `picture` and `breed_name` columns of rows 1-10 change.
--  No row is added or deleted. For a backup first:
--  phpMyAdmin -> your database -> Export -> Go.
-- ============================================================================


-- --- 1. Real photos ---------------------------------------------------------

UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/retriever-golden/n02099601_3004.jpg' WHERE id = 1;  -- Golden Retriever
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/german-shepherd/n02106662_16014.jpg' WHERE id = 2;  -- German Shepherd
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/beagle/n02088364_14613.jpg'          WHERE id = 3;  -- Beagle
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/husky/n02110185_9001.jpg'            WHERE id = 4;  -- Siberian Husky
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/poodle-standard/n02113799_4904.jpg'  WHERE id = 5;  -- Poodle
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/shihtzu/n02086240_1770.jpg'          WHERE id = 6;  -- Shih Tzu
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/collie-border/n02106166_117.jpg'     WHERE id = 7;  -- Border Collie
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/chihuahua/n02085620_11696.jpg'       WHERE id = 8;  -- Chihuahua
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/chihuahua/n02085620_13964.jpg'       WHERE id = 9;  -- Chihuahua (was "DChihuahua")
UPDATE dogbreeds SET picture = 'https://images.dog.ceo/breeds/boxer/n02108089_11032.jpg'           WHERE id = 10; -- Boxer


-- --- 2. Spelling ------------------------------------------------------------

UPDATE dogbreeds SET breed_name = 'Chihuahua' WHERE id = 9;


-- --- 3. Check the result ----------------------------------------------------
-- Expected: no via.placeholder.com anywhere, and no "DChihuahua".

SELECT id, breed_name, picture FROM dogbreeds ORDER BY id;


-- ============================================================================
--  Optional: rows 8 and 9 are now duplicates
-- ============================================================================
--  Both are "Chihuahua", Toy, Mexico. That is fine — the app lists whatever is
--  in the table — but two identical entries look odd on the Explore screen.
--  If you would rather have one, delete the spare (cannot be undone; export a
--  backup first):
--
--    DELETE FROM dogbreeds WHERE id = 9;
--
--  The app then shows 9 breeds. Nothing breaks: every count on screen is
--  worked out from the data.
-- ============================================================================
