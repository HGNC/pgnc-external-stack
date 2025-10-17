#!/bin/bash
set -e

echo "Waiting for database to be ready..."

MAX_RETRIES=30
RETRY_INTERVAL=2
retry_count=0

while [ $retry_count -lt $MAX_RETRIES ]; do
    if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
        echo "Database is ready!"
        break
    fi
    
    retry_count=$((retry_count + 1))
    echo "Attempt $retry_count/$MAX_RETRIES failed. Retrying in $RETRY_INTERVAL seconds..."
    sleep $RETRY_INTERVAL
done

if [ $retry_count -eq $MAX_RETRIES ]; then
    echo "Failed to connect to database after $MAX_RETRIES attempts"
    exit 1
fi

echo "Database connection successful, proceeding with update script..."
# Now run the actual update script
exec /usr/src/app/bin/update.sh