CREATE TABLE Tasks (
	TaskId TEXT PRIMARY KEY,
	ParentTaskId TEXT REFERENCES Tasks (TaskId),
	MaxXP INT NOT NULL
);



CREATE TABLE Peers (
	Nickname TEXT PRIMARY KEY,
	Birthday TEXT
);

CREATE TABLE Friends (
	ID SERIAL PRIMARY KEY,
	Peer1 TEXT NOT NULL REFERENCES Peers (Nickname),
	Peer2 TEXT NOT NULL REFERENCES Peers (Nickname)
);

CREATE TABLE Recommendations (
	ID SERIAL PRIMARY KEY,
	Peer TEXT NOT NULL REFERENCES Peers (Nickname),
	RecommendedPeer TEXT NOT NULL REFERENCES Peers (Nickname)
);

CREATE TABLE TransferredPoints (
	ID SERIAL PRIMARY KEY,
	CheckingPeer TEXT NOT NULL REFERENCES Peers (Nickname),
	CheckedPeer TEXT NOT NULL REFERENCES Peers (Nickname),
	PointsAmount INT NOT NULL
);

CREATE TABLE TimeTracking (
	ID SERIAL PRIMARY KEY,
	Peer TEXT NOT NULL REFERENCES Peers (Nickname),
	Date_state DATE NOT NULL DEFAULT CURRENT_DATE,
	Time_state TIME NOT NULL DEFAULT CURRENT_TIME,
	Peer_state INT CHECK (peer_state IN (1, 2))
);

CREATE TABLE Checks (
	ID SERIAL PRIMARY KEY,
	Peer TEXT NOT NULL REFERENCES Peers (Nickname),
	TaskId TEXT NOT NULL REFERENCES Tasks (TaskId),
	CheckDate DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TYPE CheckStatus AS ENUM ('Start', 'Success', 'Failure');
CREATE TABLE P2P (
	ID SERIAL PRIMARY KEY,
	CheckId BIGINT NOT NULL REFERENCES Checks (ID),
	CheckingPeer TEXT NOT NULL REFERENCES Peers (Nickname),
	CheckState CheckStatus,
	CheckTime TIME NOT NULL DEFAULT CURRENT_TIME
);

CREATE TABLE XP (
	ID SERIAL PRIMARY KEY,
	CheckId BIGINT NOT NULL REFERENCES Checks(ID),
	XPAmount INT NOT NULL
);

CREATE TABLE Verter (
	ID SERIAL PRIMARY KEY,
	CheckId BIGINT NOT NULL REFERENCES Checks(ID),
	CheckState CheckStatus,
	CheckTime TIME NOT NULL DEFAULT CURRENT_TIME
);

-- Import / Export

CREATE OR REPLACE PROCEDURE import_csv_data(
        IN table_name VARCHAR(50),
        IN file_path VARCHAR(255),
        IN delimiter VARCHAR(50)
    ) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
        'COPY %I FROM %L DELIMITER %L CSV',
        table_name,
        file_path,
        delimiter
    );
END;
$$;

CREATE OR REPLACE PROCEDURE export_csv_data(
        IN table_name VARCHAR(50),
        IN file_path VARCHAR(255),
        IN delimiter VARCHAR(50)
    ) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
        'COPY %I TO %L WITH (FORMAT CSV, DELIMITER %L)',
        table_name,
        file_path,
        delimiter
    );
END;
$$;

SET path_project.var TO '/Users/gryffind/Desktop/Projects/SQL_info';
CALL import_csv_data(
    'peers',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Peers.csv',
    ','
);
CALL import_csv_data(
    'tasks',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Tasks.csv',
    ','
);
CALL import_csv_data(
    'checks',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Checks.csv',
    ','
);
CALL import_csv_data(
    'p2p',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/P2P.csv',
    ','
);
CALL import_csv_data(
    'verter',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Verter.csv',
    ','
);
CALL import_csv_data(
    'transferredpoints',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Transfered_points.csv',
    ','
);
CALL import_csv_data(
    'friends',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Friends.csv',
    ','
);
CALL import_csv_data(
    'recommendations',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Recomendations.csv',
    ','
);
CALL import_csv_data(
    'xp',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Xp.csv',
    ','
);
CALL import_csv_data(
    'timetracking',
    CURRENT_SETTING('path_project.var') || '/src/import_csv/Time_tracking.csv',
    ','
);

-- Export to CSV
CALL export_csv_data(
    'peers',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Peers.csv',
    ','
);
CALL export_csv_data(
    'tasks',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Tasks.csv',
    ','
);
CALL export_csv_data(
    'checks',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Checks.csv',
    ','
);
CALL export_csv_data(
    'p2p',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/P2P.csv',
    ','
);
CALL export_csv_data(
    'verter',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Verter.csv',
    ','
);
CALL export_csv_data(
    'transfered_points',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Transfered_points.csv',
    ','
);
CALL export_csv_data(
    'friends',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Friends.csv',
    ','
);
CALL export_csv_data(
    'recomendations',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Recomendations.csv',
    ','
);
CALL export_csv_data(
    'xp',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Xp.csv',
    ','
);
CALL export_csv_data(
    'time_tracking',
    CURRENT_SETTING('path_project.var') || '/src/export_csv/Time_tracking.csv',
    ','
);


















