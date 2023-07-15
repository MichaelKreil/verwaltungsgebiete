#!/usr/bin/env bash
cd "$(dirname "$0")"

mkdir -p "tmp"

function process_folder() {
	SUFFIX=$1
	DATE="${SUFFIX:0:2}-${SUFFIX:2:2}"
	echo "process folder $DATE"
	url="https://daten.gdz.bkg.bund.de/produkte/vg/vg250_ebenen_$SUFFIX/"
	years=$(curl -s $url | sed -n "s/^.*href=\"\([0-9]\{4\}\).*$/\1/p")
	
	function process_year {
		YEAR=$1
		echo "   process year $YEAR"
		mkdir -p "data/$YEAR-$DATE"
		
		function ensure_data() {
			filename="tmp/$YEAR-$DATE.zip"
			if test -f "$filename"; then
				return
			fi
			url="https://daten.gdz.bkg.bund.de/produkte/vg/vg250_ebenen_$SUFFIX/$YEAR/vg250_$DATE.gk3.shape.ebenen.zip"
			
			echo -n " downloading…"
			mkdir -p "tmp/$YEAR-$DATE"
			wget -q "$url" -O $filename
			
			echo -n " unzipping…"
			unzip -qq $filename -d "tmp/$YEAR-$DATE"
		}

		function process_layer() {
			NAME=$1
			EXPRESSION=$2
			FILENAME_OUT="data/$YEAR-$DATE/$NAME.geojson.br"

			if test -f "$FILENAME_OUT"; then
				return
			fi

			echo -n "      process layer $NAME:"

			ensure_data

			FILENAME_IN=$(find tmp/$YEAR-$DATE -type f $EXPRESSION)

			if [ -z "$FILENAME_IN" ]; then
				echo "PANIK"
				exit
			fi

			echo -n " convert…"
			ogr2ogr -t_srs EPSG:4326 -lco COORDINATE_PRECISION=6 tmp/tmp1.geojson "$FILENAME_IN"

			echo -n " cleanup…"
			jq -cr '.' tmp/tmp1.geojson > tmp/tmp2.geojson

			echo -n " compress…"
			brotli -Zc tmp/tmp2.geojson > tmp/tmp3.geojson.br

			mv tmp/tmp3.geojson.br $FILENAME_OUT
			echo " ✅"
		}

		process_layer "1_bundeslaender" '-name vg250lnd.shp'
		process_layer "2_regierungsbezirke" '-name vg250bez.shp'
		process_layer "3_kreise" '-name vg250krs.shp'
		process_layer "4_verwaltungsgemeinschaften" '-name vg250amt.shp'
		process_layer "5_gemeinden" '-name vg250gem.shp'
	}

	while IFS= read -r YEAR; do
		process_year $YEAR
	done <<<"$years"

	exit
}

process_folder "1231"
process_folder "0101"
