#!/bin/sh
set -e
LIMIT=300
CLUSTER="nexarprod"
OUTPUT_FILE="$(mktemp)"

if [ -n "$1" ]; then
	CLUSTER="$1"
fi


DATA=""
PTR="0"
COUNT=0
TOTAL_COUNT=0
update_data() {
	DATA="$(cloud-vehicle list --cluster $CLUSTER --limit $LIMIT --cursor $PTR)"
	PTR="$(echo $DATA | jq .cursor -r)"
	COUNT=$(echo $DATA | jq . | grep "N1" | wc -l)
	TOTAL_COUNT=$((COUNT + TOTAL_COUNT))
	echo $DATA | jq .vehicles[].external_id -r | grep "N1" >> $OUTPUT_FILE
}

disp_data() {
	echo $TOTAL_COUNT
}


update_data
#disp_data
while [ $COUNT -eq $LIMIT ]; do
	update_data
	#disp_data
done

echo "$TOTAL_COUNT devices found in '$CLUSTER'. Full list is available in $OUTPUT_FILE :"
head -5 $OUTPUT_FILE
echo "..."
