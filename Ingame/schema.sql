CREATE TABLE MCR_CONFIG (
	name varchar(100) PRIMARY KEY,
	value varchar(10) NOT NULL
);

INSERT INTO  MCR_CONFIG(name, value) VALUES ('compensation', 'nothing');
INSERT INTO  MCR_CONFIG(name, value) VALUES ('guaranteeRefugee', '0');
INSERT INTO  MCR_CONFIG(name, value) VALUES ('refugeePerc', '3');
INSERT INTO  MCR_CONFIG(name, value) VALUES ('city_owner', 'defender');
