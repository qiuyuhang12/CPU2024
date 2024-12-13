#!/bin/bash

# Read the judgelist from a file
judgelist=$(cat MyScript/judgelist)

for s in $judgelist; do
    # Run the reprogram.sh script
    # echo "Running reprogram.sh with argument $s"

    # ./MyScript/reprogram.sh #> MyScript/tmp 2>&1
    
    # Run the single_judge.py script with the current string as an argument
    python MyScript/single_judge.py "$s"
done