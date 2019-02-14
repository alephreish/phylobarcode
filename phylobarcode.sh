#!/bin/bash

if [ -z "$1" ]; then
	echo "Parameters file not specified" >&2
	exit 1
fi

source "$1"

if [ -z "$output" ]; then
	echo "[output] folder not specified" >&2
	exit 1
fi
if [ -z "$jobs" ]; then
	echo "Number of [jobs] not specified" >&2
	exit 1
fi
if [ -z "$input" ]; then
	echo "[input] fasta not specified" >&2
	exit 1
fi
if [ -z "$identity" ]; then
	echo "Clustering [identity] level not specified" >&2
	exit 1
fi
if [ -z "$database" ]; then
	echo "Fasta [database] not specified" >&2
	exit 1
fi
if [ -z "$taxonomy" ]; then
	echo "[taxonomy] file not specified" >&2
	exit 1
fi
if [ -z "$reference" ]; then
	echo "[reference] tree not specified" >&2
	exit 1
fi
if [ -z "$superfine" ]; then
	echo "[superfine] path not specified" >&2
	exit 1
fi

dir=$(dirname "$(readlink -f "$0")")

# rm -rf "$output"/{clstr,mafft,trimal,constr,nwk}
mkdir -p "$output"/{clstr,mafft,trimal,constr,nwk}

cd-hit -i "$input" -o "$output/cdhit" -G 1 -s 0.9 -c "$identity" -n 4

samtools faidx "$input"
awk -v output="$output" '/^>/ { c=$2; next } { gsub(/aa, >|\.\.\. (at )?/, OFS) } { print > output "/clstr/" c ".tab"}' OFS=\\t "$output/cdhit.clstr"

pick_closed_reference_otus.py -i "$input" -o "$output/otus" -r "$database" -t "$taxonomy" -f -a -O "$jobs"
Rscript "$dir"/pruneReplace.R "$reference" "$output/otus/uclust_ref_picked_otus"/*_otus.txt > "$output/reference-pruned.nwk"

processCluster() {
	local input=$1
	local output=$2
	local dir=$3
	local base=$4

	local tab=$output/clstr/$base.tab
	local mafft=$output/mafft/$base.mafft.fa
	local trimal=$output/trimal/$base.trimal.fa
	local constr=$output/constr/$base.txt
	local nwk=$output/nwk/$base.nwk

	cut -f3 "$tab" | xargs samtools faidx "$input" | MAFFT_BINARIES= mafft --globalpair --maxiterate 1000 - > "$mafft"

	if [ -s "$mafft" ]; then
		trimal -in "$mafft" -automated1 -out "$trimal"
		Rscript "$dir"/pruneCluster.R "$output/reference-pruned.nwk" "$tab" | perl "$dir"/TreeToConstraints.pl > "$constr"
		[ -s "$constr" ] && fasttree -nt -constraints "$constr" -out "$nwk" "$trimal"
	fi
}

export -f processCluster
find "$output/clstr" -type f -name '*.tab' | parallel -j"$jobs" processCluster "$input" "$output" "$dir" {/.}

"$superfine/runSuperFine.py" <(cat "$output/reference-pruned.nwk" "$output"/nwk/*.nwk) -r fml                                > "$output"/superITS.nwk
"$superfine/runSuperFine.py" <(cat "$output/reference-pruned.nwk" "$output"/nwk/*.nwk "$output"/nwk/*.nwk) -r fml            > "$output"/superITS-ITSx2.nwk
"$superfine/runSuperFine.py" <(cat "$output/reference-pruned.nwk" "$output/reference-pruned.nwk" "$output"/nwk/*.nwk) -r fml > "$output"/superITS-REFx2.nwk

