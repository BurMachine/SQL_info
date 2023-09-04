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


