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
  , name VARCHAR(50) NOT NULL UNIQUE CHECK (no_blanks(name))
  , iso_3166_1_alpha_2 CHAR(2) NOT NULL UNIQUE CHECK (LENGTH(iso_3166_1_alpha_2) = 2)
  );

INSERT INTO countries (name, iso_3166_1_alpha_2)
VALUES ('France', 'FR')
     , ('Belgium', 'BE')
     , ('United Kingdom', 'GB')
     ;

CREATE TABLE person
  ( id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
  , fname TEXT NOT NULL
  , lname TEXT NOT NULL
  , age INT NOT NULL
  );

INSERT INTO person (fname, lname, age)
VALUES ('John (pg)', 'Snow (pg)', 888)
     , ('John (pg)', 'Doe (pg)', 88)
     , ('Jane (pg)', 'Doe (pg)', 87)
     ;