#!/bin/bash

# Run main.py
echo "Running main.py..."
python3 main.py

# Check if main.py executed successfully
if [ $? -eq 0 ]; then
    echo "main.py executed successfully"
else
    echo "Error: main.py failed to execute. Skipping tests."
    exit 1
fi

# Run test1.py
echo "Running test_custom.py..."
python3 test_custom.py

if [ $? -eq 0 ]; then
    echo "test1.py executed successfully. Results saved to test_results"
else
    echo "Error: test1.py failed to execute."
    exit 1
fi

# Run test2.py
echo "Running test_directhit.py..."
python3 test_directhit.py

if [ $? -eq 0 ]; then
    echo "test2.py executed successfully. Results saved to test_results"
else
    echo "Error: test2.py failed to execute."
    exit 1
fi

# Run test3.py
echo "Running test_random.py..."
python3 test_random.py

if [ $? -eq 0 ]; then
    echo "test3.py executed successfully. Results saved to test_results."
    echo "All tests executed successfully. Automation is complete."
else
    echo "Error: test3.py failed to execute."
    exit 1
fi
