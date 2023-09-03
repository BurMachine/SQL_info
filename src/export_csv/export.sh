#!/bin/bash
# Run postegresql
/Applications/Postgres.app/Contents/MacOS/Postgres
 # Создание пользователя gryffind и предоставление ему всех прав
psql -U postgres -d postgres -c "CREATE USER gryffind WITH PASSWORD '123';"
psql -U postgres -d postgres -c "GRANT ALL ON DATABASE postgres TO gryffind;"
psql -U postgres -d postgres -c "ALTER DATABASE postgres OWNER TO gryffind;"
psql -U postgres -d postgres -c "GRANT pg_write_server_files TO gryffind;"
psql -U postgres -d postgres -c "GRANT pg_read_server_files TO gryffind;"
# Установить путь до файла part1.sql
file_path=$(cd ../../ && pwd -P)
echo $file_path
# Заменить текст "/Users/gryffind/Documents/SQL2_Info21_v1.0-1/" на путь до файла
sed -i '' "s|/Users/gryffind/Documents/SQL2_Info21_v1.0-1|$file_path|g" ../part1.sql