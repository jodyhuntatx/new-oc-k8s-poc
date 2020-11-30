CREATE USER IF NOT EXISTS test_user1 IDENTIFIED BY '1234wxyz' REQUIRE NONE;
CREATE USER IF NOT EXISTS test_user2 IDENTIFIED BY 'abcd1234' REQUIRE NONE;

# Taken from:
# https://github.com/spring-petclinic/spring-petclinic-microservices/blob/master/spring-petclinic-customers-service/src/main/resources/db/mysql/schema.sql

CREATE DATABASE IF NOT EXISTS petclinic;
GRANT ALL PRIVILEGES ON petclinic.* TO test_user1, test_user2;

USE petclinic;

CREATE TABLE IF NOT EXISTS types (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80),
  INDEX(name)
) engine=InnoDB;

CREATE TABLE IF NOT EXISTS owners (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(30),
  last_name VARCHAR(30),
  address VARCHAR(255),
  city VARCHAR(80),
  telephone VARCHAR(20),
  INDEX(last_name)
) engine=InnoDB;

CREATE TABLE IF NOT EXISTS pets (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(30),
  birth_date DATE,
  type_id INT(4) UNSIGNED NOT NULL,
  owner_id INT(4) UNSIGNED NOT NULL,
  INDEX(name),
  FOREIGN KEY (owner_id) REFERENCES owners(id),
  FOREIGN KEY (type_id) REFERENCES types(id)
) engine=InnoDB;

INSERT INTO types (name)
VALUES
("dog"),
("cat"),
("bird")
;
INSERT INTO owners (first_name, last_name, address, city, telephone)
VALUES
("Sally", "Fields", "3 Sunset Blvd.", "Los Angeles", "713-555-1212"),
("Joe", "Montana", "123 Sandhill Rd.", "San Francisco", "999-555-1212"),
("Bob", "Ross", "123 Happy Valley Dr.", "San Francisco", "999-555-1212")
;
INSERT INTO pets (name, birth_date, type_id, owner_id)
VALUES
("Uri", '2014-01-01', 1, 1),
("Lilah", '2013-01-01', 2, 2),
("Max", '2019-01-01', 3, 3)
;
