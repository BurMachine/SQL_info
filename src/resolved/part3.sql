-- 1) Write a function that returns the transfered_points table in a more human-readable form
CREATE OR REPLACE FUNCTION tp_human_view () RETURNS TABLE (
        Peer1 VARCHAR(255),
        Peer2 VARCHAR(255),
        PointsAmount INT
    ) AS $$ BEGIN RETURN QUERY
SELECT tp.checking_peer AS Peer1,
    tp.checked_peer AS Peer2,
    COALESCE(tp.points_amount, 0) - COALESCE(join_tp.points_amount, 0) AS PointsAmount
FROM transfered_points tp
    FULL JOIN transfered_points AS join_tp ON tp.checking_peer = join_tp.checked_peer
    AND join_tp.checking_peer = tp.checked_peer
WHERE tp.id < join_tp.id
    OR join_tp.id IS NULL
ORDER BY Peer1,
    Peer2;
END;
$$ LANGUAGE plpgsql;
SELECT *
FROM tp_human_view();
-- DROP FUNCTION tp_human_view;
-- 2) Write a function that returns a table of the following form: user name, name of the checked task, number of xp received
CREATE OR REPLACE FUNCTION checks_success () RETURNS TABLE (Peer VARCHAR(255), Task VARCHAR(255), Xp INT) AS $$ BEGIN RETURN QUERY
SELECT checks.peer AS Peer,
    checks.task AS Task,
    xp.xp_amount AS Xp
FROM checks
    JOIN p2p ON p2p.check_num = checks.id
    AND p2p.check_state = 'Success'
    JOIN verter ON verter.check_num = checks.id
    AND verter.check_state = 'Success'
    JOIN xp ON xp.check_num = checks.id
ORDER BY Peer;
END;
$$ LANGUAGE plpgsql;
SELECT *
FROM checks_success();
-- 3) Write a function that finds the peers who have not left campus for the whole day
CREATE OR REPLACE FUNCTION peer_not_left (target_date date) RETURNS TABLE (Peer VARCHAR(255)) AS $$ BEGIN RETURN QUERY
SELECT tt.peer AS Peer
FROM time_tracking AS tt
WHERE peer_state = 1
    AND date_state = target_date
EXCEPT
SELECT tt.peer AS Peer
FROM time_tracking AS tt
WHERE peer_state = 2
    AND date_state = target_date;
END;
$$ LANGUAGE plpgsql;
SELECT *
FROM peer_not_left('2023-06-03');
-- INSERT INTO time_tracking
-- VALUES (7, 'shoredim', '2023-06-01', '09:00:00', 1);
-- INSERT INTO time_tracking
-- VALUES (8, 'shoredim', '2023-06-02', '00:01:00', 2);
-- 4) Calculate the change in the number of peer points of each peer using the transfered_points table
CREATE OR REPLACE PROCEDURE prp_change (IN Cursor REFCURSOR = 'result_p3_t4') AS $$ BEGIN OPEN Cursor FOR WITH Peer1Trans AS (
        SELECT nickname,
            SUM(COALESCE(transfered_points.points_amount, 0)) AS sum_points
        FROM peers
            LEFT JOIN transfered_points ON transfered_points.checking_peer = peers.nickname
        GROUP BY peers.nickname
        ORDER BY nickname
    ),
    Peer2Trans AS (
        SELECT nickname,
            SUM(COALESCE(transfered_points.points_amount, 0)) AS sum_points
        FROM peers
            LEFT JOIN transfered_points ON transfered_points.checked_peer = peers.nickname
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
-- DROP PROCEDURE prp_change;
-- Check procedure
BEGIN;
CALL prp_change();
FETCH ALL
FROM "result_p3_t4";
COMMIT;
-- 5) Calculate the change in the number of peer points of each peer using the table returned by the first function from Part 3
CREATE OR REPLACE PROCEDURE prp_change_tphuman (IN Cursor REFCURSOR = 'result_p3_t5') AS $$ BEGIN OPEN Cursor FOR WITH tp_human_view AS (
        SELECT *
        FROM tp_human_view()
    ),
    Peer1Trans AS (
        SELECT nickname,
            SUM(COALESCE(tp_human_view.PointsAmount, 0)) AS sum_points
        FROM peers
            LEFT JOIN tp_human_view ON tp_human_view.Peer1 = peers.nickname
        GROUP BY peers.nickname
        ORDER BY nickname
    ),
    Peer2Trans AS (
        SELECT nickname,
            SUM(COALESCE(tp_human_view.PointsAmount, 0)) AS sum_points
        FROM peers
            LEFT JOIN tp_human_view ON tp_human_view.Peer2 = peers.nickname
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
CALL prp_change_tphuman();
FETCH ALL
FROM "result_p3_t5";
COMMIT;
-- 6) Find the most frequently checked task for each day
CREATE OR REPLACE PROCEDURE freq_checked_task (IN Cursor REFCURSOR = 'result_p3_t6') AS $$ BEGIN OPEN Cursor FOR WITH checks_count AS (
        SELECT checks.date_check,
            checks.task,
            COUNT(*) AS amount
        FROM checks
        GROUP BY checks.date_check,
            checks.task
        ORDER BY checks.date_check
    ),
    max_of_count AS (
        SELECT checks_count.date_check,
            MAX(amount) AS max
        FROM checks_count
        GROUP BY checks_count.date_check
    )
SELECT TO_CHAR(checks_count.date_check, 'DD.MM.YYYY') AS Day,
    checks_count.task AS Task
FROM checks_count
    JOIN max_of_count ON max_of_count.date_check = checks_count.date_check
WHERE max_of_count.max = checks_count.amount;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL freq_checked_task();
FETCH ALL
FROM "result_p3_t6";
COMMIT;
-- 7) Find all peers who have completed the whole given block of tasks and the completion date of the last task
CREATE OR REPLACE PROCEDURE peers_completed_block (IN Cursor REFCURSOR, block_name VARCHAR(255)) AS $$
DECLARE task_count INT := (
        SELECT COUNT(*)
        FROM tasks
        WHERE tasks.title ~ ('^' || block_name || '[0-9]' || '*')
    );
BEGIN OPEN Cursor FOR WITH peer_complete_tasks AS (
    SELECT DISTINCT ON(checks.peer, checks.task) checks.peer,
        checks.task,
        checks.date_check
    FROM checks
        JOIN p2p ON checks.id = p2p.check_num
        JOIN verter ON checks.id = verter.check_num
    WHERE checks.task ~ ('^' || block_name || '[0-9]' || '*')
        AND (
            p2p.check_state = 'Success'
            AND verter.check_state = 'Success'
        )
    ORDER BY checks.peer,
        checks.task,
        checks.date_check DESC
),
uniq_count_tasks AS (
    SELECT peer,
        COUNT(*) AS amount,
        MAX(date_check) AS day
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
BEGIN;
CALL peers_completed_block('result_p3_t7', 'DO');
FETCH ALL IN result_p3_t7;
COMMIT;
-- 8) Determine which peer each student should go to for a check.
CREATE OR REPLACE PROCEDURE rec_checked_peer (IN Cursor REFCURSOR) AS $$ BEGIN OPEN Cursor FOR WITH recommended_counts AS (
        SELECT r.recomended_peer,
            COUNT(f.peer1) AS friend_count
        FROM recomendations r
            JOIN friends f ON r.recomended_peer = f.peer2
        GROUP BY r.recomended_peer
    ),
    ranked_recommended AS (
        SELECT r.peer,
            rc.recomended_peer,
            rc.friend_count,
            ROW_NUMBER() OVER (
                PARTITION BY r.peer
                ORDER BY rc.friend_count DESC
            ) AS rank
        FROM recomendations r
            JOIN recommended_counts rc ON r.recomended_peer = rc.recomended_peer
    )
SELECT p.nickname AS Peer,
    rr.recomended_peer AS RecommendedPeer
FROM peers p
    JOIN ranked_recommended rr ON p.nickname = rr.peer
WHERE rr.rank = 1
ORDER BY p.nickname;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL rec_checked_peer('result_p3_t8');
FETCH ALL IN result_p3_t8;
COMMIT;
-- 9) Determine the percentage of peers who:
CREATE OR REPLACE PROCEDURE percent_of_peers (
        IN Cursor REFCURSOR,
        block_1 VARCHAR(255),
        block_2 VARCHAR(255)
    ) AS $$ BEGIN OPEN Cursor FOR WITH all_peers_blocks AS (
        SELECT p.nickname,
            c.task
        FROM peers p
            LEFT JOIN checks c ON p.nickname = c.peer
    ),
    peers_b1 AS (
        SELECT DISTINCT ON (a.nickname) nickname
        FROM all_peers_blocks a
        WHERE a.task ~ ('^' || block_1 || '[0-9]' || '*')
    ),
    peers_b2 AS (
        SELECT DISTINCT ON (a.nickname) nickname
        FROM all_peers_blocks a
        WHERE a.task ~ ('^' || block_2 || '[0-9]' || '*')
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
        WHERE task IS NULL
    ) AS p_null,
    only_b1 b1,
    only_b2 b2,
    both_blocks bb;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL percent_of_peers('result_p3_t9', 'DO', 'C');
FETCH ALL IN result_p3_t9;
COMMIT;
-- 10) Determine the percentage of peers who have ever successfully passed a check on their birthday
CREATE OR REPLACE PROCEDURE checks_birthday (IN Cursor REFCURSOR) AS $$ BEGIN OPEN Cursor FOR WITH amount_fail AS (
        SELECT COUNT(*) AS amount
        FROM checks c
            LEFT JOIN peers p ON c.peer = p.nickname
            LEFT JOIN p2p ON p2p.check_num = c.id
            LEFT JOIN verter v ON c.id = v.check_num
        WHERE TO_CHAR(c.date_check, 'MM.DD') = TO_CHAR(p.birthday, 'MM.DD')
            AND (
                p2p.check_state = 'Failure'
                AND (
                    v.check_state = 'Failure'
                    OR v.check_state IS NULL
                )
            )
    ),
    amount_success AS (
        SELECT COUNT(*) AS amount
        FROM checks c
            LEFT JOIN peers p ON c.peer = p.nickname
            LEFT JOIN p2p ON c.id = p2p.check_num
            LEFT JOIN verter v ON c.id = v.check_num
        WHERE TO_CHAR(c.date_check, 'MM.DD') = TO_CHAR(p.birthday, 'MM.DD')
            AND p2p.check_state = 'Success'
            AND (
                v.check_state = 'Success'
                OR v.check_state IS NULL
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
BEGIN;
CALL checks_birthday('result_p3_t10');
FETCH ALL IN result_p3_t10;
COMMIT;
-- 11) Determine all peers who did the given tasks 1 and 2, but did not do task 3
CREATE OR REPLACE PROCEDURE complete_task12_not_3(
        IN Cursor REFCURSOR,
        IN Task_1 VARCHAR(255),
        IN Task_2 VARCHAR(255),
        IN Task_3 VARCHAR(255)
    ) AS $$ BEGIN OPEN Cursor FOR WITH success_tasks AS(
        SELECT c.peer
        FROM xp
            LEFT JOIN checks c ON xp.check_num = c.id
        WHERE c.task = Task_1
            OR c.task = Task_2
        GROUP BY c.peer
        HAVING COUNT(c.task) = 2
    ),
    done_task_3 AS(
        SELECT DISTINCT c.peer
        FROM xp
            LEFT JOIN checks c ON xp.check_num = c.id
        WHERE c.task = Task_3
    )
SELECT peer
FROM success_tasks
EXCEPT
SELECT peer
FROM done_task_3;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL complete_task12_not_3('result_p3_t11', 'DO4', 'DO6', 'CPP3');
FETCH ALL IN result_p3_t11;
COMMIT;
-- 12) Using recursive common table expression, output the number of preceding tasks for each task
CREATE OR REPLACE PROCEDURE output_proceding_tasks(IN Cursor REFCURSOR) AS $$ BEGIN OPEN Cursor FOR WITH RECURSIVE amount_before AS (
        (
            SELECT t.title AS task,
                0 AS prevcount
            FROM tasks t
            WHERE t.parent_task IS NULL
        )
        UNION ALL
        (
            SELECT t.title,
                prevcount + 1
            FROM tasks t
                INNER JOIN amount_before ab ON ab.task = t.parent_task
        )
    )
SELECT *
FROM amount_before;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL output_proceding_tasks('result_p3_t12');
FETCH ALL IN result_p3_t12;
COMMIT;
-- 13) Find "lucky" days for checks. A day is considered "lucky" if it has at least N consecutive successful checks
CREATE OR REPLACE PROCEDURE lucky_days(IN Cursor REFCURSOR, N INT) AS $$ BEGIN OPEN Cursor FOR WITH filter_checks AS (
        SELECT c.id,
            c.task,
            c.date_check,
            p2p.time_check,
            p2p.check_state AS p2p_state,
            v.check_state AS v_state,
            t.max_xp
        FROM checks c
            LEFT JOIN p2p ON c.id = p2p.check_num
            AND (
                p2p.check_state = 'Success'
                OR p2p.check_state = 'Failure'
            )
            LEFT JOIN verter v ON v.check_num = c.id
            AND (
                v.check_state = 'Success'
                OR v.check_state = 'Failure'
            )
            JOIN tasks t ON t.title = c.task
        ORDER BY c.date_check,
            p2p.time_check
    ),
    case_checks AS (
        SELECT fc.id,
            fc.task,
            fc.date_check,
            fc.time_check,
            CASE
                WHEN (
                    xp.xp_amount IS NULL
                    OR xp.xp_amount < fc.max_xp * 0.8
                    OR fc.p2p_state = 'Failure'
                    OR fc.v_state = 'Failure'
                ) THEN 0
                ELSE 1
            END AS c_result
        FROM filter_checks fc
            LEFT JOIN xp ON xp.check_num = fc.id
    ),
    checks_in_orders AS (
        SELECT *,
            SUM("c_result") OVER (
                PARTITION BY date_check
                ORDER BY date_check,
                    time_check,
                    id ROWS BETWEEN N - 1 PRECEDING AND CURRENT ROW
            ) AS good_days
        FROM case_checks
    )
SELECT date_check AS lucky_days
FROM checks_in_orders
GROUP BY date_check
HAVING MAX(good_days) >= N;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL lucky_days('result_p3_t13', 3);
FETCH ALL IN result_p3_t13;
COMMIT;
-- 14) Find the peer with the highest amount of xp
CREATE OR REPLACE PROCEDURE champion_xp(IN Cursor REFCURSOR) AS $$ BEGIN OPEN Cursor FOR WITH amount_xp AS (
        SELECT c.peer,
            c.task,
            MAX(xp_amount) AS xp
        FROM xp
            LEFT JOIN checks c ON c.id = xp.check_num
        GROUP BY c.peer,
            c.task
    ),
    max_peer_tasks AS (
        SELECT ax.peer,
            SUM(xp) AS xp
        FROM amount_xp ax
        GROUP BY ax.peer
    )
SELECT *
FROM max_peer_tasks
ORDER BY xp DESC
LIMIT 1;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL champion_xp('result_p3_t14');
FETCH ALL IN result_p3_t14;
COMMIT;
-- 15) Determine the peers that came before the given time at least N times during the whole time
CREATE OR REPLACE PROCEDURE before_given_time(IN Cursor REFCURSOR, tm time, N INT) AS $$ BEGIN OPEN Cursor FOR WITH came_to_campus AS (
        SELECT peer,
            date_state
        FROM time_tracking
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
BEGIN;
CALL before_given_time('result_p3_t15', '09:00:00', 3);
FETCH ALL IN result_p3_t15;
COMMIT;
-- 16) Determine the peers who left the campus more than M times during the last N days
CREATE OR REPLACE PROCEDURE left_campus_times(IN Cursor REFCURSOR, N INT, M INT) AS $$ BEGIN OPEN Cursor FOR WITH left_the_campus AS (
        SELECT peer,
            date_state
        FROM time_tracking
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
BEGIN;
CALL left_campus_times('result_p3_t16', 36, 3);
FETCH ALL IN result_p3_t16;
COMMIT;
-- 17) Determine for each month the percentage of early entries
CREATE OR REPLACE PROCEDURE before_given_time(IN Cursor REFCURSOR) AS $$ BEGIN OPEN Cursor FOR WITH total_number_of_entries AS (
        SELECT date_trunc('month', date_state) AS month_start,
            count(*) AS total_entries,
            count(*) FILTER (
                WHERE time_state < '12:00'::time
            ) AS early_entries
        FROM time_tracking tt
            JOIN peers p ON tt.peer = p.nickname
        WHERE TO_CHAR(tt.date_state, 'MM') = TO_CHAR(p.birthday, 'MM')
            AND tt.peer_state = 1
        GROUP BY month_start
    )
SELECT to_char(t.month_start, 'Month') AS month,
    round(100.0 * early_entries / total_entries, 0) AS earlyentries
FROM total_number_of_entries t
ORDER BY month_start;
END;
$$ LANGUAGE plpgsql;
BEGIN;
CALL before_given_time('result_p3_t17');
FETCH ALL IN result_p3_t17;
COMMIT;