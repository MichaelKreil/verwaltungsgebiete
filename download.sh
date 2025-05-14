#!/usr/bin/env bash
set -e
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
			
			url="${url//2013\/vg250_12-31/2013\/vg250_31-12}" #Trottel
			url="${url//2014\/vg250_12-31/2014\/vg250_31-12}" #Trottel
			
			echo -n " downloading…"
			mkdir -p "tmp/$YEAR-$DATE"
			wget -q --show-progress "$url" -O tmp/download.zip
			mv tmp/download.zip $filename
			
			echo "      unzipping"
			unzip -qq $filename -d "tmp/$YEAR-$DATE"
		}

		function process_layer() {
			NAME=$1
			EXPRESSION="-iname vg250${2//,/.shp -or -iname vg250}.shp"
			FILENAME_OUT="data/$YEAR-$DATE/$NAME.geojson.br"

			if test -f "$FILENAME_OUT"; then
				return
			fi

			ensure_data

			echo -n "      process layer $NAME:"

			FILENAME_IN=$(find tmp/$YEAR-$DATE -type f -maxdepth 4 $EXPRESSION)

			if [ -z "$FILENAME_IN" ]; then
				echo ""
				echo "Error: could not find file"
				exit 1
			fi

			rm tmp/*.geojson 2> /dev/null || true
			echo -n " convert,"
			ogr2ogr -t_srs EPSG:4326 -lco COORDINATE_PRECISION=5 tmp/tmp1.geojson "$FILENAME_IN"

			echo -n " cleanup,"
			jq -cr '.' tmp/tmp1.geojson > tmp/tmp2.geojson

			echo -n " compress,"
			brotli -Zc tmp/tmp2.geojson > tmp/tmp3.geojson.br

			mv tmp/tmp3.geojson.br $FILENAME_OUT
			echo " ✅"
		}

		process_layer "1_bundeslaender"             'lnd,_bld,_lan'
		process_layer "2_regierungsbezirke"         'bez,_rbz'
		process_layer "3_kreise"                    'krs,_krs'
		process_layer "4_verwaltungsgemeinschaften" 'amt,_vwg'
		process_layer "5_gemeinden"                 'gem,_gem'
	}

	while IFS= read -r YEAR; do
		process_year $YEAR
	done <<<"$years"
}

process_folder "1231"
process_folder "0101"
