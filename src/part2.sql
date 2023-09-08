                                --------------------- 1 ------------------------

CREATE OR REPLACE PROCEDURE insert_data_p2p(CheckedPeer TEXT, CheckingPeer TEXT, InputTaskId TEXT, CheckState CheckStatus,
 CheckTime TIME)
LANGUAGE plpgsql
AS $$
DECLARE
    NewCheckId INT;
	NewP2PId INT;
	ExistCheckId INT;
BEGIN
    -- Найдем максимальный существующий id и увеличим его на 1
    SELECT COALESCE(MAX(id), 0) + 1 INTO NewCheckId FROM Checks;
    SELECT COALESCE(MAX(id), 0) + 1 INTO NewP2PId FROM P2P;
	
    IF CheckState = 'Start' THEN
        INSERT INTO Checks (id, peer, taskid, checkdate) VALUES (NewCheckId, CheckedPeer, InputTaskId, CURRENT_DATE);
    	INSERT INTO P2P (ID, CheckId, CheckingPeer, CheckState, CheckTime) VALUES (NewP2PId, NewCheckId, CheckingPeer, CheckState, CURRENT_TIME);
	ELSE
		SELECT Checks.id INTO ExistCheckId FROM Checks WHERE Checks.peer = CheckedPeer AND Checks.taskid = InputTaskId;
		INSERT INTO P2P (ID, CheckId, CheckingPeer, CheckState, CheckTime) VALUES (NewP2PId, ExistCheckId, CheckingPeer, CheckState, CURRENT_TIME);
    END IF;
END;
$$;

                                --------------------- 2 ------------------------
CREATE OR REPLACE PROCEDURE adding_check_verter(
        IN CheckedPeer VARCHAR(255),
        IN TaskName VARCHAR(255),
        IN CheckState CheckStatus,
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
                AND c.taskid = TaskName
            ORDER BY c.id DESC
            LIMIT 1
        ) AS current_check
        JOIN p2p ON p2p.checkid = current_check.id
    WHERE p2p.checkstate = 'Success'
    ORDER BY p2p.checktime DESC
);
verterAmount BIGINT = (
    SELECT COUNT(v.checkid)
    FROM verter v
    WHERE v.checkid = idP2PSuccess
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

CALL adding_check_verter('merylpor', 'C3', 'Start', '19:30:11');
CALL adding_check_verter('luigiket', 'C3', 'Start', '19:30:11');
CALL adding_check_verter('listat', 'C3', 'Start', '19:30:11');
CALL adding_check_verter('nohoteth', 'C3', 'Success', '17:00:11');
CALL adding_check_verter('gryffind', 'C3', 'Failure', '17:00:11');


------------------------------------- 3 ----------------------------------------------


CREATE OR REPLACE FUNCTION trigger_transferred_point() RETURNS TRIGGER AS $$
DECLARE checkedPeer VARCHAR = (
        SELECT c.peer
        FROM checks c
        WHERE c.id = NEW.checkid
    );
BEGIN
UPDATE transfered_points
SET points_amount = points_amount + 1
WHERE checkingpeer = NEW.checkingpeer
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
    WHEN(NEW.checkstate = 'Start') EXECUTE FUNCTION trigger_transferred_point();

---------------------------------------- 4 ------------------------------------------

CREATE OR REPLACE FUNCTION adding_record_xp() RETURNS TRIGGER AS $$
DECLARE idNew BIGINT = (
        SELECT p2p.checkid
        FROM p2p
        WHERE NEW.checkid = p2p.checkid
            AND p2p.checkstate = 'Success'
    );
xpAmount INT = (
    SELECT tasks.maxxp
    FROM tasks
        JOIN checks ON tasks.taskid = checks.taskid
    WHERE checks.id = NEW.checkid
);
stateVerter VARCHAR = (
    SELECT checkstate
    FROM verter
    WHERE NEW.checkid = verter.checkid
    ORDER BY checkstate DESC
    LIMIT 1
);
BEGIN 
IF xpAmount < NEW.xpamount 
	THEN RAISE NOTICE 'Xp amount more than max xp!';
	RETURN NULL;
ELSIF idNew IS NULL THEN RAISE NOTICE 'P2P check state is not Success!';
	RETURN NULL;
ELSIF stateVerter = 'Failure' OR stateVerter = 'Start' 
	THEN RAISE NOTICE 'Verter status is not Success!';
	RETURN NULL;
ELSE RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_xp BEFORE
INSERT ON xp FOR EACH ROW EXECUTE FUNCTION adding_record_xp();

INSERT INTO xp (id, checkid, xpamount)
VALUES (
        (
            SELECT MAX(id)
            FROM xp
        ) + 1,
        20,
        500
);