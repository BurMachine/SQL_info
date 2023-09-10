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

