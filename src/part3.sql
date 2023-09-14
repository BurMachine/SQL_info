-------------------  1  ------------------

CREATE OR REPLACE FUNCTION transferred_points_view () RETURNS TABLE (
        Peer1 TEXT,
        Peer2 TEXT,
        PointsAmount INT
    ) AS $$ BEGIN RETURN QUERY
SELECT tp.checkingpeer AS Peer1,
    tp.checkedpeer AS Peer2,
    COALESCE(tp.pointsamount, 0) - COALESCE(join_tp.pointsamount, 0) AS PointsAmount
FROM transferredpoints tp
    FULL JOIN transferredpoints AS join_tp ON tp.checkingpeer = join_tp.checkedpeer
    AND join_tp.checkingpeer = tp.checkedpeer
WHERE tp.id < join_tp.id
    OR join_tp.id IS NULL
ORDER BY Peer1,
    Peer2;
END;
$$ LANGUAGE plpgsql;
SELECT *
FROM transferred_points_view();


-------------------- 2 ----------------

CREATE OR REPLACE FUNCTION check_xp() RETURNS TABLE (
	Peer TEXT,
	Task TEXT,
	XP INT
) AS $$ BEGIN RETURN QUERY 
	SELECT Checks.peer AS PeerName, taskid AS Taskname, xp_count.xpamount AS XP
	FROM Checks
	JOIN XP xp_count ON Checks.id = xp_count.CheckId 
	JOIN P2P ON P2P.CheckId = Checks.id AND P2P.CheckState = 'Success'
	JOIN Verter ON Verter.CheckId = Checks.id AND Verter.CheckState = 'Success'
	ORDER BY PeerName;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM check_xp();

-------------------- 3 --------------------

-- INSERT INTO timetracking
-- VALUES (37, 'gryffind', '2023-07-01', '09:00:00', 1);
-- INSERT INTO timetracking
-- VALUES (38, 'gryffind', '2023-07-02', '00:01:00', 2);

CREATE OR REPLACE FUNCTION peer_not_left_campus (target_date date) RETURNS TABLE (Peer TEXT) 
AS $$ BEGIN RETURN QUERY
	SELECT tt.peer AS Peer
	FROM timetracking AS tt
	WHERE peer_state = 1
		AND date_state = target_date
	EXCEPT
	SELECT tt.peer AS Peer
	FROM timetracking AS tt
	WHERE peer_state = 2
		AND date_state = target_date;
END;
$$ LANGUAGE plpgsql;
SELECT *
FROM peer_not_left_campus('2023-07-01');


--------------------- 4 ---------------------

CREATE OR REPLACE PROCEDURE prp_point_change (IN Cursor REFCURSOR = 'result') AS $$ 
BEGIN OPEN Cursor FOR WITH Peer1Trans AS (
        SELECT nickname,
            SUM(COALESCE(transferredpoints.pointsamount, 0)) AS sum_points
        FROM peers
            LEFT JOIN transferredpoints ON transferredpoints.checkingpeer = peers.nickname
        GROUP BY peers.nickname
        ORDER BY nickname
    ),
    Peer2Trans AS (
        SELECT nickname,
            SUM(COALESCE(transferredpoints.pointsamount, 0)) AS sum_points
        FROM peers
            LEFT JOIN transferredpoints ON transferredpoints.checkedpeer = peers.nickname
        GROUP BY peers.nickname
        ORDER BY nickname
    )
SELECT Peer2Trans.nickname AS Peer,
    Peer2Trans.sum_points - Peer1Trans.sum_points AS ChangePoints
FROM Peer2Trans
    JOIN Peer1Trans ON Peer1Trans.nickname = Peer2Trans.nickname
ORDER BY ChangePoints DESC;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL prp_point_change();
FETCH ALL
FROM "result";
COMMIT;




--------------------------------- 5 --------------------------------------


CREATE OR REPLACE PROCEDURE prp_point_change_3 (IN Cursor REFCURSOR = 'result') AS $$ 
BEGIN OPEN Cursor FOR WITH transferred_points_view AS (
        SELECT *
        FROM transferred_points_view()
    ),
    Peer1Trans AS (
        SELECT nickname,
            SUM(COALESCE(transferred_points_view.PointsAmount, 0)) AS sum_points
        FROM peers
            LEFT JOIN transferred_points_view ON transferred_points_view.Peer1 = peers.nickname
        GROUP BY peers.nickname
        ORDER BY nickname
    ),
    Peer2Trans AS (
        SELECT nickname,
            SUM(COALESCE(transferred_points_view.PointsAmount, 0)) AS sum_points
        FROM peers
            LEFT JOIN transferred_points_view ON transferred_points_view.Peer2 = peers.nickname
        GROUP BY peers.nickname
        ORDER BY nickname
    )
SELECT Peer2Trans.nickname AS Peer,
    Peer2Trans.sum_points - Peer1Trans.sum_points AS ChangePoints
FROM Peer2Trans
    JOIN Peer1Trans ON Peer1Trans.nickname = Peer2Trans.nickname
ORDER BY ChangePoints DESC;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL prp_point_change_3();
FETCH ALL
FROM "result";
COMMIT;


------------------------------------- 6 ----------------------------------------------


 CREATE OR REPLACE PROCEDURE most_popular_task(IN Cursor REFCURSOR = 'result_p6') AS $$ 
BEGIN 
    OPEN CURSOR FOR WITH ChecksTable AS (
        SELECT Checks.CheckDate, Checks.TaskId, COUNT(*) AS amount
        FROM Checks
        GROUP BY Checks.CheckDate, Checks.TaskId
        ORDER BY checks.CheckDate
    ), 
    result_table AS (
        SELECT
            t.CheckDate,
            t.TaskId,
            t.amount
        FROM
            ChecksTable AS t
    JOIN (
        SELECT
            CheckDate,
            MAX(amount) AS max_task_count
        FROM
            ChecksTable
        GROUP BY
            CheckDate
    ) AS subquery
    ON
        t.CheckDate = subquery.CheckDate
        AND t.amount = subquery.max_task_count
    )
    SELECT CheckDate, TaskId FROM result_table;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
CALL most_popular_task();
FETCH ALL
FROM "result_p6";
-- COMMIT;



------------------------------------------ 7 -------------------------------------


CREATE OR REPLACE PROCEDURE peers_completed_block (IN Cursor REFCURSOR, block_name VARCHAR(255)) AS $$
DECLARE task_count INT := (
        SELECT COUNT(*)
        FROM tasks
        WHERE tasks.taskid ~ ('^' || block_name || '[0-9]' || '*')
);
BEGIN OPEN Cursor FOR WITH peer_complete_tasks AS (
    SELECT DISTINCT ON(checks.peer, checks.TaskId) checks.Peer,
        checks.TaskId,
        checks.CheckDate
    FROM checks
        JOIN p2p ON checks.id = p2p.checkId
        JOIN verter ON checks.id = verter.checkId
    WHERE checks.taskId ~ ('^' || block_name || '[0-9]' || '*')
        AND (
            p2p.CheckState = 'Success'
            AND verter.CheckState = 'Success'
        )
    ORDER BY checks.peer,
        checks.TaskId,
        checks.CheckDate DESC
),
uniq_count_tasks AS (
    SELECT peer,
        COUNT(*) AS amount,
        MAX(CheckDate) AS day
    FROM peer_complete_tasks
    GROUP BY peer
)
SELECT ct.peer,
    TO_CHAR(ct.day, 'dd.mm.yyyy') AS day
FROM uniq_count_tasks ct
WHERE amount = task_count
ORDER BY day;
END;
$$ LANGUAGE plpgsql;




CALL peers_completed_block('result_p7', 'DO');
FETCH ALL IN result_p7;

-------------------------------------------- 8 ------------------------------------------



