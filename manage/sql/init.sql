CREATE TABLE person
  ( id INTEGER PRIMARY KEY AUTOINCREMENT
  , fname TEXT NOT NULL
  , lname TEXT NOT NULL
  , age INT NOT NULL
  );

INSERT INTO person (fname, lname, age)
VALUES ('John', 'Snow', 999)
     , ('John', 'Doe', 99)
     , ('Jane', 'Doe', 98)
     ;
