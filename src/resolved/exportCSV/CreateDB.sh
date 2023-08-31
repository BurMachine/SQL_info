#!/bin/bash
# Run postegresql
/Applications/Postgres.app/Contents/MacOS/Postgres
 # Создание пользователя janiecee и предоставление ему всех прав
psql -U postgres -d postgres -c "CREATE USER janiecee WITH PASSWORD 'janiecee';"
psql -U postgres -d postgres -c "GRANT ALL ON DATABASE postgres TO janiecee;"
psql -U postgres -d postgres -c "ALTER DATABASE postgres OWNER TO janiecee;"
psql -U postgres -d postgres -c "GRANT pg_write_server_files TO janiecee;"
psql -U postgres -d postgres -c "GRANT pg_read_server_files TO janiecee;"
# Установить путь до файла part1.sql
file_path=$(cd ../../ && pwd -P)
echo $file_path
# Заменить текст "/Users/janiecee/Documents/SQL2_Info21_v1.0-1/" на путь до файла
sed -i '' "s|/Users/janiecee/Documents/SQL2_Info21_v1.0-1|$file_path|g" ../part1.sql