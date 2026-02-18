#!/bin/bash

N=50000

OUTPUT="employees_${N}.sql"

echo "INSERT INTO employees (id, name, email) VALUES" > "$OUTPUT"

for i in $(seq 1 $N); do
  if [ "$i" -eq "$N" ]; then
    echo "($i, 'user$i', 'user$i@example.com');" >> "$OUTPUT"
  else
    echo "($i, 'user$i', 'user$i@example.com')," >> "$OUTPUT"
  fi
done
