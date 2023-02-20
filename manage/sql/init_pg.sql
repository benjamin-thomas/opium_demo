-- This file is executed within a single transaction.
-- I'll probably split it up later.

CREATE OR REPLACE FUNCTION  no_blanks(text)
RETURNS BOOLEAN AS $$
DECLARE
  trimmed TEXT;
BEGIN
  trimmed := trim($1);
  RETURN trimmed <> '' AND trimmed = $1;
END;
$$ LANGUAGE plpgsql;

-- CREATE DOMAIN TEXT_NB AS
--    TEXT CHECK (no_blanks(value));

-- iso_3166_1_alpha_2 check is strict enough:
--   SELECT LENGTH('A '::CHAR(2)) = 1;
CREATE TABLE countries
  ( id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , name VARCHAR(50)           NOT NULL UNIQUE CHECK (no_blanks(name))
  , iso_3166_1_alpha_2 CHAR(2) NOT NULL UNIQUE CHECK (LENGTH(iso_3166_1_alpha_2) = 2)
  );

INSERT INTO countries (name, iso_3166_1_alpha_2)
VALUES ('France', 'FR')
     , ('United Kingdom', 'GB')
     , ('Belgium', 'BE')
     ;

CREATE TABLE cities
  ( id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , country_id INT   NOT NULL REFERENCES countries(id)
  , name VARCHAR(50) NOT NULL UNIQUE CHECK (no_blanks(name))
  );

INSERT INTO cities (country_id, name)
VALUES (1, 'Paris')
     , (1, 'Lyon')
     , (2, 'London')
     , (3, 'Brussels')
     ;

CREATE TABLE zip_codes
  ( id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , city_id INT      NOT NULL REFERENCES cities(id)
  , code VARCHAR(10) NOT NULL CHECK (no_blanks(code))
  );

INSERT INTO zip_codes (city_id, code)
VALUES (1, '75007')     -- Paris
     , (1, '75058')     -- Paris
     , (2, '69000')     -- Lyon
     , (2, '69001')     -- Lyon
     , (3, 'SW19 5AE')  -- London/Wimbledon
     ;

-- https://www.laposte.fr/courriers-colis/conseils-pratiques/bien-rediger-l-adresse-d-une-lettre-ou-d-un-colis
-- Max length could be 38 but some transporters in France cap at 32!
CREATE TABLE addresses
  ( id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , zip_code_id INT NOT NULL REFERENCES zip_codes(id)
  , head   VARCHAR(32) NOT NULL CHECK (no_blanks(head))
  , line1  VARCHAR(32)     NULL CHECK (no_blanks(line1))
  , line2  VARCHAR(32)     NULL CHECK (no_blanks(line2))
  , line3  VARCHAR(32)     NULL CHECK (no_blanks(line3))
  , tail   VARCHAR(32)     NULL CHECK (no_blanks(tail))
  );

INSERT INTO addresses (zip_code_id, head, line1, line2, line3, tail)
VALUES (1, 'Tour Eiffel', 'Champ de Mars', '5 Av. Anatole France', NULL, NULL)
     , (2, 'Musée du Louvre', NULL, NULL, NULL, 'CEDEX 01')
     , (5, 'All England Lawn Tennis', ' & Croquet Club', 'Wimbledon', NULL, NULL)
;

CREATE TABLE person
  ( id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , fname TEXT NOT NULL
  , lname TEXT NOT NULL
  , age INT    NOT NULL
  );

INSERT INTO person (fname, lname, age)
VALUES ('John (pg)', 'Snow (pg)', 888)
     , ('John (pg)', 'Doe (pg)', 88)
     , ('Jane (pg)', 'Doe (pg)', 87)
     ;