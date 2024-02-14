# Validator Gateway Log Tools

Some tools for tracking relay-proxy performance for MEV-Boost clients

### Getting Started

**Prior to connecting to the relay proxy ensure you use the `--debug` flag with mev-boost**

After you have the debug output from mev-boost logs you can use the provided `parse_mev_boost_logs.sh` script to generate the following output:

`slots.csv:`
A CSV that includes the following fields for each slot delivered through the relay-proxy
``` text/csv
slot, relay_proxy_bid, second_highest_bid, percentage_difference, total_difference
```

`summary.csv:`
A CSV that includes the following fields, summarizing all of hte blocks delivered through the relay proxy
```
total_blocks, relay_proxy_blocks, total_eth, total_extra_eth, average_percentage_difference
```

### Running the script

`./parse_mev_boost_logs.sh /path/to/logs`

This will output the above CSVs providing you some insights into your added performance using the relay-proxy!
