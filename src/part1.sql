CREATE TABLE Peers (
	Nickname TEXT PRIMARY KEY,
	Birthday TEXT
);

CREATE TABLE Friends (
	ID SERIAL PRIMARY KEY,
	Peer1 TEXT,
	Peer2 TEXT
);

CREATE TABLE Recommendations (
	ID SERIAL PRIMARY KEY,
	Peer TEXT,
	RecommendedPeer TEXT
);

CREATE TABLE TimeTracking (
	ID SERIAL PRIMARY KEY,
	Peer TEXT,
	Date_state DATE NOT NULL DEFAULT CURRENT_DATE,
	Peer_state INT CHECK (peer_state IN (1, 2))
);

CREATE TABLE TransferredPoints (
	ID SERIAL PRIMARY KEY,
	CheckingPeer TEXT,
	CheckedPeer TEXT,
	PointsAmount INT
);

CREATE TYPE CheckStatus AS ENUM ('Start', 'Success', 'Failure');
CREATE TABLE P2P (
	ID SERIAL PRIMARY KEY,
	CheckId BIGINT NOT NULL,
	CheckingPeer TEXT,
	CheckState CheckStatus,
	CheckTime TIME NOT NULL DEFAULT CURRENT_TIME
);

CREATE TABLE Checks (
	ID SERIAL PRIMARY KEY,
	Peer TEXT,
	TaskId TEXT,
	CheckDate DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE Tasks (
	ID SERIAL PRIMARY KEY,
	ParentTask BIGINT NOT NULL,
	MaxXP INT NOT NULL
);

CREATE TABLE XP (
	ID SERIAL PRIMARY KEY,
	CheckId BIGINT NOT NULL,
	XPAmount INT NOT NULL
);

CREATE TABLE Verter (
	ID SERIAL PRIMARY KEY,
	CheckId BIGINT NOT NULL,
	CheckState CheckStatus,
	CheckTime TIME NOT NULL DEFAULT CURRENT_TIME
);





















