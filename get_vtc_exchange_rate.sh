#!/bin/bash
# 
# Trivial temporary workaround to get HUE/USD exchange rate in native Bitpay JSON format for coinpunk.
#
# Yes, this is a very ugly and inneficient hack. Feel free to improve or rewrite in dilmapunk directly.
#
# Add to Cron for the dilmapunk user via "crontab -u dilmapunk -e" to get new pricing every 15 mins
# 0,15,30,45 * * * * /path/to/get_vtc_exchange_rate.sh >> /path/to/vtcusd.log 2>&1
#
# 
# Edit your dilmapunk config.json and change pricesUrl to http://localhost:8080/rates.json
#
#set -x

. /etc/profile

# Where to write stuff
TMPDIR=/tmp
OUTPUTFILE=/home/dilmapunk/dilmapunk/public/rates.json

PID=$$

# Functions
clean_up () {
	rm $TMPDIR/*.tmp.$PID
}

get_btc_rates () {
echo "Getting BTC Exchange Rates from Bitpay..."
curl -s -f --retry 5 "https://bitpay.com/api/rates" > $TMPDIR/rates.tmp.$PID
STATUS=$?
BTCRATES=`cat $TMPDIR/rates.tmp.$PID`
}

calc_btc_usd () {
echo "Isolating BTC Price..."
BTCUSD="`echo $BTCRATES | awk -F\} '{print $1}' | awk -F: '{print $4}'`"
BTCUSD=${BTCUSD//[[:space:]]/}
echo "Current BTC Value is \$$BTCUSD..."
}

get_vtc_btc () {
echo "Getting Cryptsy HUE-BTC Exchange Rate..."
#curl --retry 5 "http://pubapi.cryptsy.com/api.php?method=singlemarketdata\&marketid=151" > $TMPDIR/cryptsy.tmp.$PID
#cat $TMPDIR/cryptsy.tmp.$PID |  awk -F, '{print $4}'|awk -F\" '{print $4}' > $TMPDIR/vtcbtc.tmp.$PID
# Single Order Data API seems to be marginally more reliable...
curl -s -f --retry 5 "http://pubapi.cryptsy.com/api.php?method=singleorderdata&marketid=151" > $TMPDIR/cryptsy.tmp.$PID
cat $TMPDIR/cryptsy.tmp.$PID | awk -F :\" '{print $8}'|cut -b 1-8 > $TMPDIR/vtcbtc.tmp.$PID
HUEBTC=`cat $TMPDIR/vtcbtc.tmp.$PID`
HUEBTC=${HUEBTC//[[:space:]]/}
}

output_vtc_usd () {
echo "Current HUE exchange rate is $HUEBTC BTC..."
echo "Converting HUE-BTC to HUE-USD..."
HUEUSD=$(echo "scale=4; $BTCUSD*$HUEBTC" | bc)
echo "Current HUE value in USD is \$$HUEUSD"
echo "Writing HUE/USD rate to local file..."
echo -n '[{"code":"USD","name":"US Dollar","rate":' > $OUTPUTFILE
echo -n $HUEUSD >> $OUTPUTFILE
echo "}]" >> $OUTPUTFILE
}

# Let's Go

# Get BTC Rates from BitPay
echo "Started $0 on `date +%c`"
get_btc_rates

if [[ ! -z "$BTCRATES" ]] ; then
	# Isolate USD value from API output
	calc_btc_usd
	# Get HUE/BTC Rate from Cryptsy
	get_vtc_btc
	if [[ ! -z "$HUEBTC" ]] ; then
		# Calcualte HUE/USD
		output_vtc_usd
	else
		echo "Cryptsy API appears to be down. Curl exited with status $STATUS..."
		clean_up
		echo "Unable to convert, please try again later."
		exit 1
	fi
else
	echo "Bitpay API appears to be down. Curl exited with status $STATUS..."
	clean_up
	echo "Unable to convert, please try again later."
	exit 1
fi

clean_up
echo "Finished!"
exit 0
