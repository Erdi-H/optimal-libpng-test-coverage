# 🖼️ PNG Test Suite Optimizer

A Bash script that picks the best 50 PNG files from a test suite to get the highest code coverage when testing the C library **libpng** with `pngtest` and `gcov`.

- Finds and tests all PNGs in `test-suite-folder/`  
- Selects files using a greedy optimization approach  
- Saves the chosen files in `optimal_50_pngs.txt`  
- Prints a final coverage report  

## Usage
```bash
chmod +x optimal_finder.sh
./optimal_finder.sh
