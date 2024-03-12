#!/bin/bash

# File containing the log data
LOG_FILE=$1

declare -a highest_bid
declare -a highest_bid_relay
declare -a all_bids

summary_file="summary.csv"
slots_file="slots.csv"

# Process the log file line by line with filtering for 'getHeader' and 'getPayload'
while IFS= read -r line
do
    # Extract slot, value, url, and relays
    slot=$(echo "$line" | sed -n 's/.*slot=\([0-9]*\).*/\1/p')
    value=$(echo "$line" | sed -n 's/.*value=\([0-9.]*\).*/\1/p')
    url=$(echo "$line" | sed -n 's/.*url="\([^"]*\).*/\1/p')
    urlBackSlash=$(echo "$line" | sed -n 's/.*url=\\"\([^"]*\).*/\1/p')
    relays=$(echo "$line" | sed -n 's/.*relays="\([^"]*\).*/\1/p')
    relaysBackSlash=$(echo "$line" | sed -n 's/.*relays=\\"\([^"]*\).*/\1/p')

    # Skip line if slot or value is empty
    if [ -z "$slot" ] || [ -z "$value" ]; then
        continue
    fi

    # Use relay information if available, else use URL
    relay_or_url="$url"
    if [ -n "$relays" ]; then
        relay_or_url="$relays"
    fi
    
    if [ -n "$urlBackSlash" ]; then
        relay_or_url="$urlBackSlash"
    fi

    if [ -n "$relaysBackSlash" ]; then
        relay_or_url="$relaysBackSlash"
    fi


    # Store all bids for the slot with their URLs or relays
    all_bids[$slot]="${all_bids[$slot]}$value|$relay_or_url "

    # Check if we have a new highest bid for the slot
    if [[ -z ${highest_bid[$slot]} ]] || (( $(echo "$value > ${highest_bid[$slot]}" | bc -l) )); then
        highest_bid[$slot]=$value
        highest_bid_relay[$slot]=$relay_or_url
    fi
done < <(grep -e 'getHeader' -e 'getPayload' "$LOG_FILE" | grep -v 'ignoring bid with 0 value')


# Create summary file
echo "slot,relay_proxy_bid,second_highest_bid,percentage_difference,total_difference" > $slots_file

total_blocks=0
total_relay_proxy_blocks=0
total_difference=0
average_percentage_difference=0
total_eth=0

# Display results
for slot in "${!highest_bid[@]}"
do
    total_blocks=$((total_blocks+1))

    if [ -z "${highest_bid_relay[$slot]}" ] || [[ "${highest_bid_relay[$slot]}" != *'relay-proxy'* ]]; then
        continue
    fi

    total_relay_proxy_blocks=$((total_relay_proxy_blocks+1))
    total_eth=$(echo "$total_eth + ${highest_bid[$slot]}" | bc -l)
    
    slot_second_highest_bid=0
    slot_second_highest_bid_relay=""
    difference=0
    percentage_difference=0


    for bid in ${all_bids[$slot]}
    do
        if [[ $bid == *'|'* ]] && [[ $bid != *'relay-proxy'* ]]; then
            value=${bid%|*}
            if [[ $value == ${highest_bid[$slot]} ]]; then
                continue
            fi
            relay_or_url=${bid#*|}
            if [[ $relay_or_url != ${highest_bid_relay[$slot]} ]]; then
              if (( $(echo "$value > $slot_second_highest_bid" | bc -l) )); then
                slot_second_highest_bid=$value
                slot_second_highest_bid_relay=$relay_or_url
              fi
            fi
        fi
    done

    # echo "Second Highest Bid: $slot_second_highest_bid"
    if !(( $(echo "$slot_second_highest_bid == 0" | bc -l) )); then
        difference=$(echo "${highest_bid[$slot]} - $slot_second_highest_bid" | bc -l)
        percentage_difference=$(echo "scale=5; ((${highest_bid[$slot]} - $slot_second_highest_bid) / $slot_second_highest_bid) * 100" | bc -l)
    fi

    total_difference=$(echo "$total_difference + $difference" | bc -l)
    average_percentage_difference=$(echo "scale=5; $average_percentage_difference + $percentage_difference" | bc -l)

    echo "$slot,${highest_bid[$slot]},$slot_second_highest_bid,$percentage_difference,$difference" >> $slots_file
done


average_percentage_difference=$(echo "scale=5; $average_percentage_difference / $total_relay_proxy_blocks" | bc -l)

echo "total_blocks,relay_proxy_blocks,total_eth,total_extra_eth,average_percentage_difference" > $summary_file
echo "$total_blocks,$total_relay_proxy_blocks,$total_eth,$total_difference,$average_percentage_difference" >> $summary_file
