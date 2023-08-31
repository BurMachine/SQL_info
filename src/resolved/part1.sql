DROP OWNED BY janiecee;
CREATE TABLE peers (
    nickname VARCHAR(255) PRIMARY KEY,
    birthday DATE NOT NULL
);
CREATE TABLE tasks (
    title VARCHAR(255) PRIMARY KEY,
    parent_task VARCHAR(255),
    max_xp INT NOT NULL
);
CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');
CREATE TABLE checks (
    id SERIAL PRIMARY KEY,
    peer VARCHAR(255) NOT NULL,
    task VARCHAR(255) NOT NULL,
    date_check DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE TABLE p2p (
    id SERIAL PRIMARY KEY,
    check_num BIGINT NOT NULL,
    checking_peer VARCHAR(255) NOT NULL,
    check_state check_status,
    time_check TIME NOT NULL DEFAULT CURRENT_TIME
);
CREATE TABLE verter (
    id SERIAL PRIMARY KEY,
    check_num BIGINT NOT NULL,
    check_state check_status NOT NULL,
    time_check TIME NOT NULL DEFAULT CURRENT_TIME
);
CREATE TABLE transfered_points (
    id SERIAL PRIMARY KEY,
    checking_peer VARCHAR(255) NOT NULL,
    checked_peer VARCHAR(255) NOT NULL,
    points_amount INT NOT NULL
);
CREATE TABLE friends (
    id SERIAL PRIMARY KEY,
    peer1 VARCHAR(255) NOT NULL,
    peer2 VARCHAR(255) NOT NULL
);
CREATE TABLE recomendations (
    id SERIAL PRIMARY KEY,
    peer VARCHAR(255) NOT NULL,
    recomended_peer VARCHAR(255) NOT NULL
);
CREATE TABLE xp (
    id SERIAL PRIMARY KEY,
    check_num BIGINT NOT NULL,
    xp_amount INT NOT NULL
);
CREATE TABLE time_tracking (
    id SERIAL PRIMARY KEY,
    peer VARCHAR(255) NOT NULL,
    date_state DATE NOT NULL NOT NULL DEFAULT CURRENT_DATE,
    time_state TIME NOT NULL DEFAULT CURRENT_TIME,
    peer_state INT CHECK (peer_state IN (1, 2))
);
-- FK peer and task
-- TABLE CHECKS
ALTER TABLE checks
ADD CONSTRAINT fk_checks_peer FOREIGN KEY (peer) REFERENCES peers(nickname),
    ADD CONSTRAINT fk_checks_task FOREIGN KEY (task) REFERENCES tasks(title);
-- TABLE FRIENDS
ALTER TABLE friends
ADD CONSTRAINT fk_friend_peer1 FOREIGN KEY (peer1) REFERENCES peers(nickname),
    ADD CONSTRAINT fk_friend_peer2 FOREIGN KEY (peer2) REFERENCES peers(nickname),
    ADD CONSTRAINT uk_peer1_peer2 CHECK (peer1 <> peer2);
-- TABLE P2P
ALTER TABLE p2p
ADD CONSTRAINT fk_p2p_check_num FOREIGN KEY (check_num) REFERENCES checks(id),
    ADD CONSTRAINT fk_p2p_checking_peer FOREIGN KEY (checking_peer) REFERENCES peers(nickname),
    ADD CONSTRAINT uk_p2p_check UNIQUE (check_num, checking_peer, check_state);
-- TABLE RECOMENDATIONS
ALTER TABLE recomendations
ADD CONSTRAINT fk_recomendations_peer FOREIGN KEY (peer) REFERENCES peers(nickname),
    ADD CONSTRAINT fk_recomendations_recomended_peer FOREIGN KEY (recomended_peer) REFERENCES peers(nickname);
-- TABLE TASKS
ALTER TABLE tasks
ADD CONSTRAINT fk_tasks_parent_task FOREIGN KEY (parent_task) REFERENCES tasks(title);
-- TABLE TIME_TRACKING
ALTER TABLE time_tracking
ADD CONSTRAINT fk_time_tracking_peer FOREIGN KEY (peer) REFERENCES peers(nickname);
-- TABLE TRANSFERED_POINTS
ALTER TABLE transfered_points
ADD CONSTRAINT fk_transfered_points_checking_peer FOREIGN KEY (checking_peer) REFERENCES peers(nickname),
    ADD CONSTRAINT fk_transfered_points_checked_peer FOREIGN KEY (checked_peer) REFERENCES peers(nickname);
-- TABLE VERTER
ALTER TABLE verter
ADD CONSTRAINT fk_verter_check_num FOREIGN KEY (check_num) REFERENCES checks(id);
-- TABLE XP
ALTER TABLE xp
ADD CONSTRAINT fk_xp_check_num FOREIGN KEY (check_num) REFERENCES checks(id);
-- Create procedure to import in csv file
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
-- Create procedure to export from csv file 
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
-- Run from SU POSTGRES (sudo su postgres; psql; GRANT pg_write_server_files TO postgres; GRANT pg_read_server_files TO postgres;)
SET path_project.var TO '/Users/janiecee/Documents/SQL2_Info21_v1.0-1';
CALL import_csv_data(
    'peers',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Peers.csv',
    ','
);
CALL import_csv_data(
    'tasks',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Tasks.csv',
    ','
);
CALL import_csv_data(
    'checks',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Checks.csv',
    ','
);
CALL import_csv_data(
    'p2p',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/P2P.csv',
    ','
);
CALL import_csv_data(
    'verter',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Verter.csv',
    ','
);
CALL import_csv_data(
    'transfered_points',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Transfered_points.csv',
    ','
);
CALL import_csv_data(
    'friends',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Friends.csv',
    ','
);
CALL import_csv_data(
    'recomendations',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Recomendations.csv',
    ','
);
CALL import_csv_data(
    'xp',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Xp.csv',
    ','
);
CALL import_csv_data(
    'time_tracking',
    CURRENT_SETTING('path_project.var') || '/src/importCSV/Time_tracking.csv',
    ','
);
-- Export to CSV
CALL export_csv_data(
    'peers',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Peers.csv',
    ','
);
CALL export_csv_data(
    'tasks',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Tasks.csv',
    ','
);
CALL export_csv_data(
    'checks',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Checks.csv',
    ','
);
CALL export_csv_data(
    'p2p',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/P2P.csv',
    ','
);
CALL export_csv_data(
    'verter',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Verter.csv',
    ','
);
CALL export_csv_data(
    'transfered_points',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Transfered_points.csv',
    ','
);
CALL export_csv_data(
    'friends',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Friends.csv',
    ','
);
CALL export_csv_data(
    'recomendations',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Recomendations.csv',
    ','
);
CALL export_csv_data(
    'xp',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Xp.csv',
    ','
);
CALL export_csv_data(
    'time_tracking',
    CURRENT_SETTING('path_project.var') || '/src/exportCSV/Time_tracking.csv',
    ','
);