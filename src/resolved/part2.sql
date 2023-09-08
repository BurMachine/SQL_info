-- 1) Write a procedure for adding p2p check
CREATE OR REPLACE PROCEDURE adding_check_p2p(
        IN CheckedPeer VARCHAR(255),
        IN CheckingPeer VARCHAR(255),
        IN TaskName VARCHAR(255),
        IN CheckState p2p.check_state %TYPE,
        IN TimeCheck TIME
    ) AS $$
DECLARE idStart BIGINT = (
        SELECT id
        FROM (
                SELECT p.check_num,
                    p.check_state
                FROM p2p p
                WHERE p.checking_peer = CheckingPeer
            ) AS p2pStart
            LEFT JOIN (
                SELECT c.id
                FROM checks c
                WHERE c.peer = CheckedPeer
                    AND c.task = TaskName
            ) AS checks_peer_task ON p2pStart.check_num = checks_peer_task.id
        GROUP BY id
        HAVING COUNT(check_state) = 1
    );
idCheckLast BIGINT = (
    SELECT MAX(id)
    FROM checks
);
idNew BIGINT = (COALESCE(idCheckLast, 0));
idP2PLast BIGINT = (
    SELECT MAX(id)
    FROM p2p
);
BEGIN IF CheckState = 'Start' THEN IF idStart IS NOT NULL THEN RAISE NOTICE 'This "%" task "%" peer and "%" checking peer in the "Start" status already exist!',
TaskName,
CheckedPeer,
CheckingPeer;
ELSE idNew = idNew + 1;
INSERT INTO checks (id, peer, task, date_check)
VALUES (
        idNew,
        CheckedPeer,
        TaskName,
        CURRENT_DATE
    );
INSERT INTO p2p (
        id,
        check_num,
        checking_peer,
        check_state,
        time_check
    )
VALUES (
        COALESCE(idP2PLast, 0) + 1,
        idNew,
        CheckingPeer,
        CheckState,
        TimeCheck
    );
END IF;
ELSE IF idStart IS NOT NULL THEN
INSERT INTO p2p (
        id,
        check_num,
        checking_peer,
        check_state,
        time_check
    )
VALUES (
        COALESCE(idP2PLast, 0) + 1,
        idStart,
        CheckingPeer,
        CheckState,
        TimeCheck
    );
ELSE RAISE NOTICE 'This "%" task "%" peer and "%" checking peer was not started!',
TaskName,
CheckedPeer,
CheckingPeer;
END IF;
END IF;
END;
$$ LANGUAGE plpgsql;
-- 2) Write a procedure for adding checking by verter
CREATE OR REPLACE PROCEDURE adding_check_verter(
        IN CheckedPeer VARCHAR(255),
        IN TaskName VARCHAR(255),
        IN CheckState p2p.check_state %TYPE,
        IN TimeCheck TIME
    ) AS $$
DECLARE idVerterLast BIGINT = (
        SELECT COALESCE(MAX(id), 0)
        FROM verter
    );
idP2PSuccess BIGINT = (
    SELECT current_check.id
    FROM (
            SELECT *
            FROM checks c
            WHERE c.peer = CheckedPeer
                AND c.task = TaskName
            ORDER BY c.id DESC
            LIMIT 1
        ) AS current_check
        JOIN p2p ON p2p.check_num = current_check.id
    WHERE p2p.check_state = 'Success'
    ORDER BY p2p.time_check DESC
);
verterAmount BIGINT = (
    SELECT COUNT(v.check_num)
    FROM verter v
    WHERE v.check_num = idP2PSuccess
);
BEGIN IF idP2PSuccess IS NULL THEN RAISE NOTICE 'This "%" task with "%" peer is not in the "Success" P2P status!',
TaskName,
CheckedPeer;
ELSEIF CheckState = 'Start' THEN IF verterAmount = 0 THEN
INSERT INTO verter (id, check_num, check_state, time_check)
VALUES (
        idVerterLast + 1,
        idP2PSuccess,
        CheckState,
        TimeCheck
    );
ELSE RAISE NOTICE 'This "%" task with "%" peer is already in the "Start" Verter status!',
TaskName,
CheckedPeer;
END IF;
ELSE IF verterAmount = 1 THEN
INSERT INTO verter (id, check_num, check_state, time_check)
VALUES (
        idVerterLast + 1,
        idP2PSuccess,
        CheckState,
        TimeCheck
    );
ELSIF verterAmount = 0 THEN RAISE NOTICE 'This "%" task with "%" peer is not in the "Start" Verter status!',
TaskName,
CheckedPeer;
ELSE RAISE NOTICE 'This "%" task with "%" peer is already checked by Verter!',
TaskName,
CheckedPeer;
END IF;
END IF;
END;
$$ LANGUAGE plpgsql;
-- 3) Write a trigger: after adding a record with the "start" check_state to the p2p table, change the corresponding record in the transfered_points table
CREATE OR REPLACE FUNCTION trigger_transferred_point() RETURNS TRIGGER AS $$
DECLARE checkedPeer VARCHAR = (
        SELECT c.peer
        FROM checks c
        WHERE c.id = NEW.check_num
    );
BEGIN
UPDATE transfered_points
SET points_amount = points_amount + 1
WHERE checking_peer = NEW.checking_peer
    AND checked_peer = checkedPeer;
IF NOT FOUND THEN
INSERT INTO transfered_points (id, checking_peer, checked_peer, points_amount)
VALUES (
        (
            SELECT MAX(tp.id)
            FROM transfered_points tp
        ) + 1,
        NEW.checking_peer,
        checkedPeer,
        1
    );
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- trigger
CREATE TRIGGER trg_transferred_point
AFTER
INSERT ON p2p FOR EACH ROW
    WHEN(NEW.check_state = 'Start') EXECUTE FUNCTION trigger_transferred_point();
-- 4) Write a trigger: before adding a record to the XP table, check if it is correct
CREATE OR REPLACE FUNCTION adding_record_xp() RETURNS TRIGGER AS $$
DECLARE idNew BIGINT = (
        SELECT p2p.check_num
        FROM p2p
        WHERE NEW.check_num = p2p.check_num
            AND p2p.check_state = 'Success'
    );
xpAmount INT = (
    SELECT tasks.max_xp
    FROM tasks
        JOIN checks ON tasks.title = checks.task
    WHERE checks.id = NEW.check_num
);
stateVerter VARCHAR = (
    SELECT check_state
    FROM verter
    WHERE NEW.check_num = verter.check_num
    ORDER BY check_state DESC
    LIMIT 1
);
BEGIN IF xpAmount < NEW.xp_amount THEN RAISE NOTICE 'Xp amount more than max xp!';
RETURN NULL;
ELSIF idNew IS NULL THEN RAISE NOTICE 'P2P check state is not Success!';
RETURN NULL;
ELSIF stateVerter = 'Failure'
OR stateVerter = 'Start' THEN RAISE NOTICE 'Verter status is not Success!';
RETURN NULL;
ELSE RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;
-- trigger
CREATE TRIGGER trg_xp BEFORE
INSERT ON xp FOR EACH ROW EXECUTE FUNCTION adding_record_xp();
-- CHECK 1 PROCEDURE
-- CASE 1 check state "Start"
CALL adding_check_p2p(
    'charisho',
    'charlesl',
    'C3',
    'Start',
    '11:20:00'
);
CALL adding_check_p2p(
    'charisho',
    'charlesl',
    'C3',
    'Start',
    '11:20:00'
);
-- CASE 2 check state "Success/Failure"
CALL adding_check_p2p(
    'charisho',
    'charlesl',
    'C3',
    'Success',
    '11:20:00'
);
CALL adding_check_p2p(
    'charisho',
    'charlesl',
    'C3',
    'Success',
    '11:20:00'
);
CALL adding_check_p2p(
    'charisho',
    'charlesl',
    'C3',
    'Failure',
    '11:20:00'
);
-- CHECK 2 PROCEDURE AND 3 TRIGGER
-- CASE 1 p2p dont have 'Success'
CALL adding_check_p2p(
    'merylpor',
    'shoredim',
    'C3',
    'Start',
    '19:25:00'
);
CALL adding_check_verter('shoredim', 'C3', 'Start', '17:00:11');
-- CASE 2 verter dont have 'Start'
CALL adding_check_verter('shoredim', 'C3', 'Success', '17:00:11');
CALL adding_check_verter('shoredim', 'C3', 'Failure', '17:00:11');
-- CASE 3 verter have 'Start' already
CALL adding_check_p2p(
    'merylpor',
    'shoredim',
    'C3',
    'Success',
    '19:26:00'
);
CALL adding_check_verter('merylpor', 'C3', 'Start', '19:30:11');
CALL adding_check_verter('merylpor', 'C3', 'Start', '19:30:11');
-- CASE 4 verter 'Success' or 'Failure' already
CALL adding_check_verter('merylpor', 'C3', 'Success', '17:00:11');
CALL adding_check_verter('merylpor', 'C3', 'Failure', '17:00:11');
-- CHECK 4 TRIGGER
-- CASE 1 verter 'Success' or 'Failure' already
INSERT INTO xp (id, check_num, xp_amount)
VALUES (
        (
            SELECT MAX(id)
            FROM xp
        ) + 1,
        20,
        600
);