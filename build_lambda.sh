#!/bin/bash
set -e

# Output zip path (relative to project root)
PACKAGE_ZIP="lambda_package.zip"

echo "Building Lambda package fully inside Docker..."

docker run --rm -v "$PWD":/var/task --entrypoint /bin/bash public.ecr.aws/lambda/python:3.11 -c "
    yum install -y zip >/dev/null 2>&1

    # Work in a temporary directory inside container
    mkdir /tmp/build
    cd /tmp/build

    # Install dependencies into build dir
    pip install --no-cache-dir -r /var/task/lambda/requirements.txt -t .

    # Copy your Lambda function code
    cp /var/task/lambda/src.py .

    # Zip everything
    zip -r /var/task/$PACKAGE_ZIP .
"

echo "Lambda package built successfully: $PACKAGE_ZIP"




