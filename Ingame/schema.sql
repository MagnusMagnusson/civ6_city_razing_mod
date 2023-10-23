CREATE TABLE MCR_CONFIG (
	name varchar(100) PRIMARY KEY,
	value varchar(10) NOT NULL
);

--default values--
INSERT INTO TABLE MCR_CONFIG(name, value) VALUES ('giveSettler', "0");
INSERT INTO TABLE MCR_CONFIG(name, value) VALUES ('guaranteeRefugee', "0");
INSERT INTO TABLE MCR_CONFIG(name, value) VALUES ('refugeePerc', "7");