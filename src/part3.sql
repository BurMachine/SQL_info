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

CREATE OR REPLACE PROCEDURE recommended_checked_peer (IN Cursor REFCURSOR) AS $$ BEGIN OPEN Cursor FOR WITH recommended_counts AS (
        SELECT r.recommendedpeer,
            COUNT(f.peer1) AS friend_count
        FROM recommendations r
            JOIN friends f ON r.recommendedpeer = f.peer2
        GROUP BY r.recommendedpeer
    ),
    ranked_recommended AS (
        SELECT r.peer,
            rc.recommendedpeer,
            rc.friend_count,
            ROW_NUMBER() OVER (
                PARTITION BY r.peer
                ORDER BY rc.friend_count DESC
            ) AS rank
        FROM recommendations r
            JOIN recommended_counts rc ON r.recommendedpeer = rc.recommendedpeer
    )
SELECT p.nickname AS Peer,
    rr.recommendedpeer AS RecommendedPeer
FROM peers p
    JOIN ranked_recommended rr ON p.nickname = rr.peer
WHERE rr.rank = 1
ORDER BY p.nickname;
END;

$$ LANGUAGE plpgsql;

CALL recommended_checked_peer('result_p8');
FETCH ALL IN result_p8;


--------------------------------------------- 9 --------------------------------------------



CREATE OR REPLACE PROCEDURE percent_of_peers_block (
        IN Cursor REFCURSOR,
        block_1 VARCHAR(255),
        block_2 VARCHAR(255)
    ) AS $$ BEGIN OPEN Cursor FOR WITH all_peers_blocks AS (
        SELECT p.nickname,
            c.TaskId
        FROM peers p
            LEFT JOIN checks c ON p.nickname = c.peer
    ),
    peers_b1 AS (
        SELECT DISTINCT ON (a.nickname) nickname
        FROM all_peers_blocks a
        WHERE a.TaskId ~ ('^' || block_1 || '[0-9]' || '*')
    ),
    peers_b2 AS (
        SELECT DISTINCT ON (a.nickname) nickname
        FROM all_peers_blocks a
        WHERE a.TaskId ~ ('^' || block_2 || '[0-9]' || '*')
    ),
    only_b2 AS(
        SELECT COUNT(b21.nickname) AS StartedBlock2
        FROM (
                SELECT b2.nickname
                FROM peers_b2 b2
                EXCEPT
                SELECT b1.nickname
                FROM peers_b1 b1
            ) AS b21
    ),
    only_b1 AS(
        SELECT COUNT(b12.nickname) AS StartedBlock1
        FROM (
                SELECT b1.nickname
                FROM peers_b1 b1
                EXCEPT
                SELECT b2.nickname
                FROM peers_b2 b2
            ) AS b12
    ),
    both_blocks AS (
        SELECT COUNT(bb.nickname) AS StartedBothBlocks
        FROM (
                SELECT b1.nickname
                FROM peers_b1 b1
                    JOIN peers_b2 b2 ON b2.nickname = b1.nickname
            ) AS bb
    )
SELECT ROUND(
        CAST(b1.StartedBlock1 AS NUMERIC) / CAST(p.amount AS NUMERIC) * 100,
        0
    ) AS "StartedBlock1",
    ROUND(
        CAST(b2.StartedBlock2 AS NUMERIC) / CAST(p.amount AS NUMERIC) * 100,
        0
    ) AS "StartedBlock2",
    ROUND(
        CAST(bb.StartedBothBlocks AS NUMERIC) / CAST(p.amount AS NUMERIC) * 100,
        0
    ) AS "StartedBothBlocks",
    ROUND(
        CAST(p_null.amount AS NUMERIC) / CAST(p.amount AS NUMERIC) * 100,
        0
    ) AS "DidntStartAnyBlock"
FROM (
        SELECT COUNT(peers.nickname) AS amount
        FROM peers
    ) AS p,
    (
        SELECT COUNT(ap.nickname) AS amount
        FROM all_peers_blocks ap
        WHERE TaskId IS NULL
    ) AS p_null,
    only_b1 b1,
    only_b2 b2,
    both_blocks bb;
END;
$$ LANGUAGE plpgsql;

CALL percent_of_peers_block('result_p9', 'DO', 'C');
FETCH ALL IN result_p9;


----------------------------- 10 -------------------------------------


CREATE OR REPLACE PROCEDURE checks_birthday (IN Cursor REFCURSOR) AS $$ BEGIN OPEN Cursor FOR 
WITH amount_fail AS (
    SELECT COUNT(*) AS amount
    FROM checks c
        LEFT JOIN peers p ON c.peer = p.nickname
        LEFT JOIN p2p ON p2p.CheckId = c.id
        LEFT JOIN verter v ON c.id = v.CheckId
    WHERE TO_CHAR(c.CheckDate, 'MM.DD') = p.birthday 
        AND (
            p2p.CheckState = 'Failure'
            AND (
                v.CheckState = 'Failure'
                OR v.CheckState IS NULL
            )
        )
),
amount_success AS (
    SELECT COUNT(*) AS amount
    FROM checks c
        LEFT JOIN peers p ON c.peer = p.nickname
        LEFT JOIN p2p ON c.id = p2p.CheckId
        LEFT JOIN verter v ON c.id = v.CheckId
    WHERE TO_CHAR(c.CheckDate, 'MM.DD') = p.birthday
        AND p2p.CheckState = 'Success'
        AND (
            v.CheckState = 'Success'
            OR v.CheckState IS NULL
        )
)
SELECT ROUND(
        100 * a_s.amount / NULLIF(a_s.amount + af.amount, 0),
        0
    ) AS SuccessfulChecks,
    ROUND(
        100 * af.amount / NULLIF(a_s.amount + af.amount, 0),
        0
    ) AS UnsuccessfulChecks
FROM amount_fail af,
    amount_success a_s;
END;
$$ LANGUAGE plpgsql;

CALL checks_birthday('result_p10');
FETCH ALL IN result_p10;


----------------------------------- 11 --------------------------------------

CREATE OR REPLACE PROCEDURE complete_task12_not_3(
        IN Cursor REFCURSOR,
        IN Task_1 VARCHAR(255),
        IN Task_2 VARCHAR(255),
        IN Task_3 VARCHAR(255)
    ) AS $$ BEGIN OPEN Cursor FOR WITH success_tasks AS(
        SELECT c.peer
        FROM xp
            LEFT JOIN checks c ON xp.CheckId = c.id
        WHERE c.TaskId = Task_1
            OR c.TaskId = Task_2
        GROUP BY c.peer
        HAVING COUNT(c.TaskId) = 2
    ),
    done_task_3 AS(
        SELECT DISTINCT c.peer
        FROM xp
            LEFT JOIN checks c ON xp.CheckId = c.id
        WHERE c.TaskId = Task_3
    )
SELECT peer
FROM success_tasks
EXCEPT
SELECT peer
FROM done_task_3;
END;
$$ LANGUAGE plpgsql;

CALL complete_task12_not_3('result_p11', 'DO4', 'DO6', 'CPP3');
FETCH ALL IN result_p11;


---------------------------------- 12 -----------------------------------------------


CREATE OR REPLACE PROCEDURE output_proceding_tasks(IN Cursor REFCURSOR) AS $$ 
BEGIN OPEN Cursor FOR WITH RECURSIVE amount_before AS (
	(
		SELECT t.TaskId AS task,
			0 AS prevcount
		FROM tasks t
		WHERE t.parenttaskid IS NULL
	)
	UNION ALL
	(
		SELECT t.TaskId,
			prevcount + 1
		FROM tasks t
			INNER JOIN amount_before ab ON ab.task = t.parenttaskId
	)
)
SELECT *
FROM amount_before;
END;
$$ LANGUAGE plpgsql;

CALL output_proceding_tasks('result_p12');
FETCH ALL IN result_p12;

--------------------------------------- 13 ------------------------------------------

CREATE OR REPLACE PROCEDURE lucky_days(IN Cursor REFCURSOR, N INT) AS $$ BEGIN OPEN Cursor FOR WITH filter_checks AS (
        SELECT c.id,
            c.taskId,
            c.CheckDate,
            p2p.CheckTime,
            p2p.CheckState AS p2p_state,
            v.CheckState AS v_state,
            t.maxXp
        FROM checks c
            LEFT JOIN p2p ON c.id = p2p.CheckId
            AND (
                p2p.checkState = 'Success'
                OR p2p.checkState = 'Failure'
            )
            LEFT JOIN verter v ON v.checkId = c.id
            AND (
                v.checkState = 'Success'
                OR v.checkState = 'Failure'
            )
            JOIN tasks t ON t.TaskId = c.taskId
        ORDER BY c.CheckDate,
            p2p.CheckTime
    ),
    case_checks AS (
        SELECT fc.id,
            fc.taskId,
            fc.CheckDate,
            fc.CheckTime,
            CASE
                WHEN (
                    xp.xpAmount IS NULL
                    OR xp.xpAmount < fc.maxXp * 0.8
                    OR fc.p2p_state = 'Failure'
                    OR fc.v_state = 'Failure'
                ) THEN 0
                ELSE 1
            END AS c_result
        FROM filter_checks fc
            LEFT JOIN xp ON xp.checkId = fc.id
    ),
    checks_in_orders AS (
        SELECT *,
            SUM("c_result") OVER (
                PARTITION BY CheckDate
                ORDER BY CheckDate,
                    CheckTime,
                    id ROWS BETWEEN N - 1 PRECEDING AND CURRENT ROW
            ) AS good_days
        FROM case_checks
    )
SELECT CheckDate AS lucky_days
FROM checks_in_orders
GROUP BY CheckDate
HAVING MAX(good_days) >= N;
END;
$$ LANGUAGE plpgsql;

CALL lucky_days('result_p3_t13', 3);
FETCH ALL IN result_p3_t13;


------------------------------------------------- 14 --------------------------------------------



CREATE OR REPLACE PROCEDURE before_given_time(IN Cursor REFCURSOR, tm time, N INT) AS $$ 
BEGIN OPEN Cursor FOR WITH came_to_campus AS (
        SELECT peer,
            date_state
        FROM timeTracking
        WHERE peer_state = 1
            AND time_state < tm
        GROUP BY peer,
            date_state
    )
SELECT peer
FROM came_to_campus
GROUP BY peer
HAVING COUNT(peer) >= N;
END;
$$ LANGUAGE plpgsql;

CALL before_given_time('result_p15', '09:00:00', 3);
FETCH ALL IN result_p15;


------------------------------------------------- 15 ---------------------------------------------


CREATE OR REPLACE PROCEDURE before_time(IN Cursor REFCURSOR, tm time, N INT) AS $$ 
BEGIN OPEN Cursor FOR WITH came_to_campus AS (
        SELECT peer,
            date_state
        FROM timeTracking
        WHERE peer_state = 1
            AND time_state < tm
        GROUP BY peer,
            date_state
    )
SELECT peer
FROM came_to_campus
GROUP BY peer
HAVING COUNT(peer) >= N;
END;
$$ LANGUAGE plpgsql;

CALL before_time('result_p15', '09:00:00', 3);
FETCH ALL IN result_p15;

------------------------------------------------ 16 ----------------------------------------------

CREATE OR REPLACE PROCEDURE left_campus_times(IN Cursor REFCURSOR, N INT, M INT) AS $$ 
BEGIN OPEN Cursor FOR WITH left_the_campus AS (
        SELECT peer,
            date_state
        FROM timeTracking
        WHERE peer_state = 2
            AND (CURRENT_DATE - date_state) < N
        GROUP BY peer,
            date_state
    )
SELECT peer
FROM left_the_campus
GROUP BY peer
HAVING COUNT(peer) > M;
END;
$$ LANGUAGE plpgsql;

CALL left_campus_times('result_p16', 36, 3);
FETCH ALL IN result_p16;


-------------------------------------------------- 17 --------------------------------------------

CREATE OR REPLACE PROCEDURE before_given_time(IN Cursor REFCURSOR) AS $$ 
BEGIN OPEN Cursor FOR WITH total_number_of_entries AS (
        SELECT date_trunc('month', date_state) AS month_start,
            count(*) AS total_entries,
            count(*) FILTER (
                WHERE time_state < '12:00'::time
            ) AS early_entries
        FROM timeTracking tt
            JOIN peers p ON tt.peer = p.nickname
        WHERE TO_CHAR(tt.date_state, 'MM') = p.birthday
            AND tt.peer_state = 1
        GROUP BY month_start
    )
SELECT to_char(t.month_start, 'Month') AS month,
    round(100.0 * early_entries / total_entries, 0) AS earlyentries
FROM total_number_of_entries t
ORDER BY month_start;
END;
$$ LANGUAGE plpgsql;

CALL before_given_time('result_p17');
FETCH ALL IN result_p17;
