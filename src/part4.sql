-- Сreating tables whose names have the same prefix for exponential pressure
BEGIN;
DROP OWNED BY gryffind;
CREATE TABLE IF NOT EXISTS "TableName1" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName2" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName3" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName4" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName5" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName6" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName_no" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableFName_no" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableNamCe_no" (id SERIAL PRIMARY KEY, header VARCHAR(50));

-- TableName1
CREATE OR REPLACE FUNCTION func1(
        head VARCHAR(50) default 'Default Table'
    ) RETURNS void AS $$
INSERT INTO "TableName1"(header)
VALUES(head);
$$ LANGUAGE SQL;
SELECT func1();
SELECT *
FROM "TableName1";

-- TableName2
CREATE OR REPLACE FUNCTION func2(
        head VARCHAR(50) default 'Default Table'
    ) RETURNS void AS $$
INSERT INTO "TableName2"(header)
VALUES(head);
$$ LANGUAGE SQL;
SELECT func2();
SELECT *
FROM "TableName2";

-- TableName3
CREATE OR REPLACE FUNCTION func3(
        head VARCHAR(50) default 'Default Table'
    ) RETURNS void AS $$
INSERT INTO "TableName3"(header)
VALUES(head);
$$ LANGUAGE SQL;
SELECT func3();
SELECT *
FROM "TableName3";


-- TableName4
CREATE OR REPLACE PROCEDURE procedure1(
        head VARCHAR(50) default 'Default Table'
    ) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
        'INSERT INTO "TableName4"(header)
VALUES(%L)',
        head
    );
END;
$$;
CALL procedure1();
SELECT *
FROM "TableName4";

-- TableName5
CREATE OR REPLACE PROCEDURE procedure2(
        head VARCHAR(50) default 'Default Table'
    ) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
        'INSERT INTO "TableName5"(header)
VALUES(%L)',
        head
    );
END;
$$;
CALL procedure2();
SELECT *
FROM "TableName5";

-- TableName6
CREATE OR REPLACE PROCEDURE procedure3(
        head VARCHAR(50) default 'Default Table'
    ) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
        'INSERT INTO "TableName6"(header)
VALUES(%L)',
        head
    );
END;
$$;
CALL procedure3();
SELECT *
FROM "TableName6";


-- TRIGGERS
CREATE OR REPLACE FUNCTION fnc_handle() RETURNS TRIGGER AS $$ BEGIN IF (TG_OP = 'INSERT') 
THEN NEW.header = 'gryffind';
    RETURN NEW;
ELSIF (TG_OP = 'UPDATE') THEN NEW.header = 'gryffind';
    RETURN NEW;
ELSIF (TG_OP = 'DELETE') THEN RETURN OLD;
END IF;
END;
$$ LANGUAGE plpgsql;
-- trigger 1
CREATE TRIGGER trigger1 BEFORE
INSERT
    OR
UPDATE
    OR DELETE ON "TableName_no" FOR EACH ROW EXECUTE FUNCTION fnc_handle();
-- trigger 2
CREATE TRIGGER trigger2 BEFORE
INSERT
    OR
UPDATE
    OR DELETE ON "TableFName_no" FOR EACH ROW EXECUTE FUNCTION fnc_handle();
-- trigger 3
CREATE TRIGGER trigger3 BEFORE
INSERT
    OR
UPDATE
    OR DELETE ON "TableNamCe_no" FOR EACH ROW EXECUTE FUNCTION fnc_handle();
COMMIT;


-------------------------------------- 1 -------------------------------------------------
-- Procedure that destroys all tables whose names have 'TableName' prefix, without doestouing database.

BEGIN;
CREATE OR REPLACE PROCEDURE destroy_tables(Prefix text) AS $$
DECLARE loopRecord text;
    BEGIN FOR loopRecord IN
        SELECT quote_ident(table_name)
        FROM information_schema.tables
        WHERE table_schema LIKE 'public'
            AND table_type = 'BASE TABLE'
            AND table_name LIKE (Prefix || '%') LOOP EXECUTE 'DROP TABLE IF EXISTS ' || loopRecord || ' CASCADE';
    RAISE NOTICE 'Table deleted: %',
    quote_ident(loopRecord);
END LOOP;
END;
$$ LANGUAGE plpgsql;
CALL destroy_tables('TableName');
COMMIT;

---------------------------------------- 2 -------------------------------------------------
--  Procedure that getting all scalar functions on this database.

BEGIN;
CREATE OR REPLACE PROCEDURE output_functions(INOUT AmountFuncs INTEGER) AS $$ BEGIN DROP TABLE IF EXISTS tempTable;
CREATE TEMP TABLE tempTable AS
SELECT MAX(routines.routine_name) AS func_name,
    string_agg(
        parameters.parameter_name,
        ', '
        ORDER BY parameters.ordinal_position
    ) AS function_parameters
FROM information_schema.routines
    LEFT JOIN information_schema.parameters ON routines.specific_name = parameters.specific_name
WHERE routines.specific_schema = 'public'
    AND routine_type = 'FUNCTION'
    AND parameter_name IS NOT NULL
GROUP BY parameters.specific_name
ORDER BY func_name;
SELECT COUNT(*)
FROM tempTable INTO AmountFuncs;
END;
$$ LANGUAGE plpgsql;
DO $$
DECLARE AmountFuncs INTEGER;
BEGIN CALL output_functions(AmountFuncs);
RAISE NOTICE '%',
AmountFuncs;
END;
$$;
SELECT *
FROM tempTable;
COMMIT;

----------------------------------------------- 3 ----------------------------------------------
-- Drop all DML Triggers in this DataBase

BEGIN;
CREATE OR REPLACE PROCEDURE destroy_triggers(INOUT AmountTriggers INTEGER) AS $$
    DECLARE loopRecord record;
    BEGIN AmountTriggers := 0;
    FOR loopRecord IN
    SELECT quote_ident(trigger_name) || ' ON ' || quote_ident(event_object_table) AS comm_to_drop
    FROM information_schema.triggers
    WHERE trigger_schema = 'public'
    GROUP BY trigger_name,
    event_object_table LOOP BEGIN AmountTriggers := AmountTriggers + 1;
EXECUTE 'DROP TRIGGER ' || loopRecord.comm_to_drop || ';';
EXCEPTION
    WHEN OTHERS THEN AmountTriggers := AmountTriggers - 1;
    END;
END LOOP;
END;
$$ LANGUAGE plpgsql;
DO $$
DECLARE AmountTriggers INTEGER;
    BEGIN CALL destroy_triggers(AmountTriggers);
    RAISE NOTICE '%',
    AmountTriggers;
END;
$$;
COMMIT;



----------------------------------------------- 4 ------------------------------------------------

BEGIN;
CREATE OR REPLACE PROCEDURE desc_objects_proc(IN StringPattern TEXT) 
AS $$ BEGIN DROP TABLE IF EXISTS tempTable;
	CREATE TEMP TABLE tempTable AS
	SELECT routine_name AS rname,
    	routine_type AS rtype,
    	routine_definition
	FROM information_schema.routines
	WHERE routines.specific_schema = 'public'
    AND routine_definition ILIKE '%' || StringPattern || '%'
    AND routine_body = 'SQL'
    AND (
        routine_type = 'FUNCTION'
        OR routine_type = 'PROCEDURE'
    )
	ORDER BY rname;
END;
$$ LANGUAGE plpgsql;
CALL desc_objects_proc('(');
SELECT *
FROM tempTable;
COMMIT;


