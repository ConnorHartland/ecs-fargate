#!/bin/bash
# Fix compliance tags - replace commas with plus signs

find terraform/modules -name "*.tf" -type f -exec sed -i 's/Compliance = "\([^"]*\),\([^"]*\)"/Compliance = "\1+\2"/g' {} \;
find terraform/modules -name "*.tf" -type f -exec sed -i 's/Compliance = "\([^"]*\),\([^"]*\)"/Compliance = "\1+\2"/g' {} \;
find terraform/modules -name "*.tf" -type f -exec sed -i 's/Compliance = "\([^"]*\),\([^"]*\)"/Compliance = "\1+\2"/g' {} \;

echo "Fixed all Compliance tags"
