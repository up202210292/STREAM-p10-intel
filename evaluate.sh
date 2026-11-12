
#!/usr/bin/env bash

THREAD_COUNTS="${THREAD_COUNTS:-96 64 32 16 8 4 2}"
STREAM_ARRAY_SIZE="${STREAM_ARRAY_SIZE:-$((512 * 1024 * 1024))ull}"

set -euo pipefail

OUTPUT="stream_results.csv"
EXECUTABLE="stream_c.exe"

# Memory kinds to test
KINDS=("MEMKIND_REGULAR" "MEMKIND_HBW_ALL")

# CSV header
echo "MEMKIND_A,MEMKIND_B,MEMKIND_C,OMP_NUM_THREADS,Function,Best_Rate_MB_s,Avg_time,Min_time,Max_time" > "$OUTPUT"

# Iterate over all memory placement combinations
for A in "${KINDS[@]}"; do
    for B in "${KINDS[@]}"; do
        for C in "${KINDS[@]}"; do

            echo "========================================"
            echo "Testing A=$A B=$B C=$C"
            echo "========================================"

            for THREADS in $THREAD_COUNTS; do

                echo "Running with $THREADS threads..."

                # Compile
                rm -f "$EXECUTABLE"

                CFLAGS="-DMEMKIND_A=$A -DMEMKIND_B=$B -DMEMKIND_C=$C -DSTREAM_ARRAY_SIZE=$STREAM_ARRAY_SIZE" \
                    make "$EXECUTABLE" > /dev/null

                # Execute and capture output
                OUTPUT_TEXT=$(OMP_NUM_THREADS=$THREADS ./"$EXECUTABLE")

                # Extract STREAM results
                echo "$OUTPUT_TEXT" | awk -v A="$A" -v B="$B" -v C="$C" -v T="$THREADS" '
                    /^(Copy|Scale|Add|Triad):/ {
                        function_name = $1
                        sub(/:$/, "", function_name)

                        print A "," B "," C "," T "," \
                              function_name "," $2 "," $3 "," $4 "," $5
                    }
                ' >> "$OUTPUT"

            done
        done
    done
done

rm -f "$EXECUTABLE"

echo "Benchmark completed. Results saved to $OUTPUT"

