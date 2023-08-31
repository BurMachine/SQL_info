-- For this part of the task, you need to create a separate database, in which to create the tables,
BEGIN;
DROP OWNED BY janiecee;
CREATE TABLE IF NOT EXISTS "TableName_1" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName_2" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName_3" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName_4" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName_5" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableName_6" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "LableName_no" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableFName_no" (id SERIAL PRIMARY KEY, header VARCHAR(50));
CREATE TABLE IF NOT EXISTS "TableNamCe_no" (id SERIAL PRIMARY KEY, header VARCHAR(50));
-- functions,
-- TableName_1
CREATE OR REPLACE FUNCTION func_1(
        head VARCHAR(50) default 'Where is my money Lebowski?'
    ) RETURNS void AS $$
INSERT INTO "TableName_1"(header)
VALUES(head);
$$ LANGUAGE SQL;
SELECT func_1();
SELECT *
FROM "TableName_1";
-- TableName_2
CREATE OR REPLACE FUNCTION func_2(
        head VARCHAR(50) default 'Where is my money Lebowski?'
    ) RETURNS void AS $$
INSERT INTO "TableName_2"(header)
VALUES(head);
$$ LANGUAGE SQL;
SELECT func_2();
SELECT *
FROM "TableName_2";
-- TableName_3
CREATE OR REPLACE FUNCTION func_3(
        head VARCHAR(50) default 'Where is my money Lebowski?'
    ) RETURNS void AS $$
INSERT INTO "TableName_3"(header)
VALUES(head);
$$ LANGUAGE SQL;
SELECT func_3();
SELECT *
FROM "TableName_3";
-- procedures,
-- TableName_4
CREATE OR REPLACE PROCEDURE procedure_1(
        head VARCHAR(50) default 'Where is my money Lebowski?'
    ) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
        'INSERT INTO "TableName_4"(header)
VALUES(%L)',
        head
    );
END;
$$;
CALL procedure_1();
SELECT *
FROM "TableName_4";
-- TableName_5
CREATE OR REPLACE PROCEDURE procedure_2(
        head VARCHAR(50) default 'Where is my money Lebowski?'
    ) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
        'INSERT INTO "TableName_5"(header)
VALUES(%L)',
        head
    );
END;
$$;
CALL procedure_2();
SELECT *
FROM "TableName_5";
-- TableName_6
CREATE OR REPLACE PROCEDURE procedure_3(
        head VARCHAR(50) default 'Where is my money Lebowski?'
    ) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
        'INSERT INTO "TableName_6"(header)
VALUES(%L)',
        head
    );
END;
$$;
CALL procedure_3();
SELECT *
FROM "TableName_6";
-- and triggers needed to test the procedures.
CREATE OR REPLACE FUNCTION fnc_handle() RETURNS TRIGGER AS $$ BEGIN IF (TG_OP = 'INSERT') THEN NEW.header = 'Jeff';
RETURN NEW;
ELSIF (TG_OP = 'UPDATE') THEN NEW.header = 'Jeff';
RETURN NEW;
ELSIF (TG_OP = 'DELETE') THEN RETURN OLD;
END IF;
END;
$$ LANGUAGE plpgsql;
-- trigger 1
CREATE TRIGGER trigger_1 BEFORE
INSERT
    OR
UPDATE
    OR DELETE ON "LableName_no" FOR EACH ROW EXECUTE FUNCTION fnc_handle();
-- trigger 2
CREATE TRIGGER trigger_2 BEFORE
INSERT
    OR
UPDATE
    OR DELETE ON "TableFName_no" FOR EACH ROW EXECUTE FUNCTION fnc_handle();
-- trigger 3
CREATE TRIGGER trigger_3 BEFORE
INSERT
    OR
UPDATE
    OR DELETE ON "TableNamCe_no" FOR EACH ROW EXECUTE FUNCTION fnc_handle();
COMMIT;
-- 1) Create a stored procedure that, without destroying the database, destroys all those tables in the current database whose names begin with the phrase 'TableName'.
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
-- 2) Create a stored procedure with an output parameter that outputs a list of names and parameters of all scalar user's SQL functions in the current database. Do not output function names without parameters. The names and the list of parameters must be in one string. The output parameter returns the number of functions found.
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
-- 3) Create a stored procedure with output parameter, which destroys all SQL DML triggers in the current database. The output parameter returns the number of destroyed triggers.
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
-- 4) Create a stored procedure with an input parameter that outputs names and descriptions of object types (only stored procedures and scalar functions) that have a string specified by the procedure parameter.
BEGIN;
CREATE OR REPLACE PROCEDURE desc_objects(IN StringPattern TEXT) AS $$ BEGIN DROP TABLE IF EXISTS tempTable;
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
CALL desc_objects('(');
SELECT *
FROM tempTable;
COMMIT;