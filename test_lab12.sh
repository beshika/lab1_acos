#!/bin/bash

SCRIPT="$(realpath ./lab12.sh)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Создание замены df. Общий размер = 100 КБ
mkdir -p "$TMP/bin"
cat > "$TMP/bin/df" <<'EOF'
#!/bin/bash
echo "Filesystem 1K-blocks Used Available Use% Mounted on"
echo "fake 100 0 100 0% /"
EOF
chmod +x "$TMP/bin/df"

PASS=0
FAIL=0
check() { # check "название теста" "условие (результат теста)"
if [ "$2" -eq 0 ]; then
 echo "PASS: $1"
 PASS=$((PASS+1))
else
 echo "FAIL: $1"
 FAIL=$((FAIL+1))
 fi
}

# run_script <path> <N> <M> -> out, code
run_script() {
out=$(echo -e "$1\n$2\n$3" | \
PATH="$TMP/bin:$PATH" BACKUP_DIR="$TMP/backup" bash "$SCRIPT" 2>&1)
code=$?
}

# создаёт папку с тремя .log по 4 КБ (файл а - самый старый)
make_logs() {
rm -rf "$1" "$TMP/backup"
mkdir -p "$1"
for f in a b c; do
 head -c 4096 /dev/zero > "$1/$f.log"
done
touch -d "2024-01-01" "$1/a.log"
touch -d "2024-02-01" "$1/b.log"
touch -d "2024-03-01" "$1/c.log"
}

# Тест 1: путь не существует 
run_script "$TMP/no_such_dir" 10 1
[ $code -eq 1 ] && echo "$out" | grep -q "does not exist"
check "1. Несуществующий путь -> ошибка, exit 1" $?

# Тест 2: путь - файл, а не папка
touch "$TMP/file.txt"
run_script "$TMP/file.txt" 10 1
[ $code -eq 1 ] && echo "$out" | grep -q "is a file"
check "2. Путь является файлом -> ошибка, exit 1" $?

# Тест 3: N не число 
make_logs "$TMP/log"
run_script "$TMP/log" "abc" 1
[ $code -eq 1 ] && echo "$out" | grep -q "must be a whole number"
check "3. Некорректный порог N -> ошибка, exit 1" $?

# Тест 4: порог не превышен, архивация пропущена
make_logs "$TMP/log" # ~12 КБ из 100 КБ = 12%
run_script "$TMP/log" 50 2
echo "Файлы 4ого теста:"
echo "Файлы в log:"
ls -la "$TMP/log"
echo "Содержимое backup:"
ls -la "$TMP/backup" 2>/dev/null
[ $code -eq 0 ] && echo "$out" | grep -q "12%" \
&& echo "$out" | grep -q "was not exceeded" \
&& [ ! -d "$TMP/backup" -o -z "$(ls -A "$TMP/backup" 2>/dev/null)" ] \
&& [ "$(ls "$TMP/log" | wc -l)" -eq 3 ]
check "4. Порог не превышен -> архива нет, файлы на месте" $?


# Тест 5: порог превышен, архивируются M старых файлов 
make_logs "$TMP/log"
run_script "$TMP/log" 10 2 # 12% > 10%, M=2
echo "Файлы 5ого теста:"
echo "Файлы в log:"
ls -la "$TMP/log"
echo "Содержимое backup:"
ls -la "$TMP/backup" 2>/dev/null

arch=$(ls "$TMP/backup"/archive_*.tar.gz 2>/dev/null | head -n1)
echo "Файлы внутри созданного архива:"
tar -tzf "$arch"

[ $code -eq 0 ] && [ -n "$arch" ] \
&& tar -tzf "$arch" | grep -q "a.log" \
&& tar -tzf "$arch" | grep -q "b.log" \
&& ! tar -tzf "$arch" | grep -q "c.log" \
&& [ ! -e "$TMP/log/a.log" ] && [ ! -e "$TMP/log/b.log" ] \
&& [ -e "$TMP/log/c.log" ]
check "5. Порог превышен -> 2 старых файла в tar.gz в backup, оригиналы удалены" $?

echo "-----"
echo "Пройдено: $PASS, провалено: $FAIL"
[ $FAIL -eq 0 ]
