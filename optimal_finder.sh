#!/bin/bash

MAX_FILES=50
BEST_SUBSET="optimal_50_pngs.txt"
TEMP_SUBSET="temp_subset.txt"

echo "Finding optimal combination of $MAX_FILES PNG files..."
echo "This may take a while, testing all combinations"

ls test-suite-folder/*.png > all_pngs.txt 2>/dev/null
TOTAL_FILES=$(wc -l < all_pngs.txt)
echo "Found $TOTAL_FILES PNG files to choose from"


test_coverage() {
    local file_list="$1"
    
    rm -f *.gcda pngout.png

    while IFS= read -r png_file; do
        if [ -f "$png_file" ]; then
            ./pngtest "$png_file" >/dev/null 2>&1
        fi
    done < "$file_list"
    
    local coverage=$(gcov *.c 2>/dev/null | tail -1 | grep -o '[0-9]*\.[0-9]*' | head -1)
    if [ -z "$coverage" ]; then
        coverage="0.0"
    fi
    echo "$coverage"
}

echo "" > "$BEST_SUBSET"
best_coverage="0.0"

echo "Starting optimization..."

# Greedy selection - add files that improve coverage most
for iteration in $(seq 1 $MAX_FILES); do
    echo "Iteration $iteration/$MAX_FILES (current best: ${best_coverage}%)"
    
    best_candidate=""
    best_new_coverage="0.0"
    tested_count=0
    
    # Try adding each remaining file
    while IFS= read -r candidate_file; do
        # Skip if already in subset
        if grep -Fxq "$candidate_file" "$BEST_SUBSET" 2>/dev/null; then
            continue
        fi
        
        # Create test subset with this candidate
        cp "$BEST_SUBSET" "$TEMP_SUBSET"
        echo "$candidate_file" >> "$TEMP_SUBSET"
        
        new_coverage=$(test_coverage "$TEMP_SUBSET")
        tested_count=$((tested_count + 1))
        
        is_better=$(awk "BEGIN {print ($new_coverage > $best_new_coverage)}")
        if [ "$is_better" = "1" ]; then
            best_new_coverage="$new_coverage"
            best_candidate="$candidate_file"
        fi
        
        # Progress indicator
        if [ $((tested_count % 20)) -eq 0 ]; then
            echo -n "."
        fi
        
    done < all_pngs.txt
    
    echo ""  

    is_improvement=$(awk "BEGIN {print ($best_new_coverage > $best_coverage)}")
    if [ -n "$best_candidate" ] && [ "$is_improvement" = "1" ]; then
        echo "$best_candidate" >> "$BEST_SUBSET"
        best_coverage="$best_new_coverage"
        echo "Added: $(basename "$best_candidate") -> Coverage: ${best_coverage}%"
    else
        echo "No improvement found in this iteration"
        # Fill remaining slots with highest individual scorers if we have space
        if [ $iteration -lt $MAX_FILES ]; then
            echo "Filling remaining slots with best individual performers..."
            
            # Test individual coverage for remaining files
            > temp_individual.txt
            while IFS= read -r candidate_file; do
                if ! grep -Fxq "$candidate_file" "$BEST_SUBSET" 2>/dev/null; then
                    echo "$candidate_file" > single_test.txt
                    individual_coverage=$(test_coverage single_test.txt)
                    echo "$individual_coverage $candidate_file" >> temp_individual.txt
                fi
            done < all_pngs.txt
            
            # Add best individual performers to fill up to MAX_FILES
            remaining_slots=$((MAX_FILES - $(grep -c . "$BEST_SUBSET")))
            if [ $remaining_slots -gt 0 ]; then
                sort -nr temp_individual.txt | head -$remaining_slots | cut -d' ' -f2- >> "$BEST_SUBSET"
            fi
            
            rm -f temp_individual.txt single_test.txt
        fi
        break
    fi
done

echo "============================================"
echo "OPTIMIZATION COMPLETE!"
echo "============================================"

echo "Testing final combination of files for detailed coverage report..."
rm -f *.gcda pngout.png

while IFS= read -r png_file; do
    if [ -f "$png_file" ]; then
        ./pngtest "$png_file" >/dev/null 2>&1
    fi
done < "$BEST_SUBSET"

detailed_coverage=$(gcov *.c 2>/dev/null | tail -1)
final_coverage=$(echo "$detailed_coverage" | grep -o '[0-9]*\.[0-9]*' | head -1)
final_count=$(grep -c . "$BEST_SUBSET")

echo "FINAL COVERAGE REPORT:"
echo "$detailed_coverage"
echo ""
echo "Coverage percentage: ${final_coverage}%"
echo "Number of files: $final_count"
echo ""
echo "OPTIMAL PNG FILES:"
echo "============================================"

while IFS= read -r file; do
    if [ -n "$file" ]; then
        echo "$(basename "$file")"
    fi
done < "$BEST_SUBSET"

echo "============================================"
echo ""
echo "Files saved to: $BEST_SUBSET"
echo ""
echo "To copy these files to submission folder:"
echo "mkdir -p submission"
echo "while read f; do cp \"\$f\" \"submission/test-suite-\$(basename \"\$f\")\"; done < $BEST_SUBSET"

rm -f all_pngs.txt "$TEMP_SUBSET" *.gcda pngout.png
