CREATE TABLE person
  ( id INTEGER PRIMARY KEY AUTOINCREMENT
  , fname TEXT NOT NULL
  , lname TEXT NOT NULL
  , age INT NOT NULL
  );

INSERT INTO person (fname, lname, age)
VALUES ('John (sqlite)', 'Snow (sqlite)', 999)
     , ('John (sqlite)', 'Doe (sqlite)', 99)
     , ('Jane (sqlite)', 'Doe (sqlite)', 98)
     ;
