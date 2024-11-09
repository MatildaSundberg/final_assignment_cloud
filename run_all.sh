#!/bin/bash

# Run main.py
echo "Running automated script..."
python3 main.py

# Check if main.py executed successfully
if [ $? -eq 0 ]; then
    echo "main.py executed successfully"
    
    # Run test.py and export results to test_results.txt
    echo "Running test.py..."
    python3 test.py > test_results.txt

    # Check if test.py executed successfully
    if [ $? -eq 0 ]; then
        echo "test.py executed successfully. Results saved to test_results.txt."
        echo "Automation is complete."
    else
        echo "Error: test.py failed to execute."
        exit 1
    fi
else
    echo "Error: main.py failed to execute. Skipping test.py."
    exit 1
fi
