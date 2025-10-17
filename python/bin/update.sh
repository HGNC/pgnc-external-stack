# Do DB data update
# Check if batch.csv exists
echo "Transfer data to DB" 2>&1 | tee output.log
if [ -f /usr/src/app/input/batch.csv ]; then
    python /usr/src/app/bin/data-load/main.py --file /usr/src/app/input/batch.csv || { echo "Data load failed" >&2; exit 1; }
    TODAY=$(date +%Y-%m-%d)
    echo "Data loaded successfully on $TODAY" 2>&1 | tee -a output.log
    mv /usr/src/app/input/batch.csv /usr/src/app/input/batch_$TODAY.csv
fi
echo "Done" 2>&1 | tee output.log

# Do Solr data update
rm -f /usr/src/app/output/done.flag solr.json
echo "Transfer data to solr" 2>&1 | tee output.log
python /usr/src/app/bin/data-update/main.py --clear 2>&1 | tee -a output.log
echo "Transfer data to dump file" 2>&1 | tee -a output.log
python /usr/src/app/bin/data-update/main.py --dump 2>&1 | tee -a output.log
