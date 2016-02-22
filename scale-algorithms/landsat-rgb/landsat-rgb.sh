#!/bin/bash

echo "Running landsat-rgb.sh " $*
red_inputfile=""
green_inputfile=""
blue_inputfile=""

# Handle arguments
while getopts ":r::g::b:" opt; do
    case $opt in
        r)
            red_inputfile=$OPTARG >&2
            ;;
        g)
            green_inputfile=$OPTARG >&2
            ;;
        b)
            blue_inputfile=$OPTARG >&2
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

# create and switch into temp directory
mkdir /tmp/data
cd /tmp/data

# Extract filenames without extensions
red_file=$(basename "${red_inputfile}")
red_filename="${red_file%.*}"
green_file=$(basename "${green_inputfile}")
green_filename="${green_file%.*}"
blue_file=$(basename "${blue_inputfile}")
blue_filename="${blue_file%.*}"

# Extract base filename without band or extension
base_filename="${red_file%_*}"

# Reproject images
gdalwarp -t_srs EPSG:3857 "${blue_inputfile}" /tmp/data/"${blue_filename}"_PROJECTED.TIF
gdalwarp -t_srs EPSG:3857 "${green_inputfile}" /tmp/data/"${green_filename}"_PROJECTED.TIF
gdalwarp -t_srs EPSG:3857 "${red_inputfile}" /tmp/data/"${red_filename}"_PROJECTED.TIF
# Combine bands into one RGB image
ls /tmp/data/"${red_filename}"_PROJECTED.TIF
convert -combine /tmp/data/"${red_filename}"_PROJECTED.TIF /tmp/data/"${green_filename}"_PROJECTED.TIF /tmp/data/"${blue_filename}"_PROJECTED.TIF /tmp/data/"${base_filename}"_RGB.TIF
# Adjust image color
convert -channel B -gamma 0.975 -channel G -gamma 0.99 -channel RGB -sigmoidal-contrast 50x13% /tmp/data/"${base_filename}"_RGB.TIF /tmp/data/"${base_filename}"_RGB_CORRECTED.TIF
# Convert to 8 bit image
convert -depth 8 /tmp/data/"${base_filename}"_RGB_CORRECTED.TIF /tmp/data/"${base_filename}"_RGB_CORRECTED_8bit.TIF
# Retrieve geo data from base image and reapply it to the corrected 8-bit RGB image
listgeo -tfw /tmp/data/"${red_filename}"_PROJECTED.TIF
mv /tmp/data/"${red_filename}"_PROJECTED.tfw /tmp/data/"${base_filename}"_RGB_CORRECTED_8bit.tfw
gdal_edit.py -a_srs EPSG:3857 /tmp/data/"${base_filename}"_RGB_CORRECTED_8bit.TIF
# Toss all input files
ls | grep -v _8bit.TIF | xargs rm

mv /tmp/data/"${base_filename}"_RGB_CORRECTED_8bit.TIF "${@: -1}"/"${base_filename}"_RGB_CORRECTED_8bit.TIF

cat > "${@: -1}"/results_manifest.json << EOF
{ "version": "1.1",
  "output_data": [{
    "name": "landsat-rgb",
    "file": {
        "path": "${@: -1}/${base_filename}_RGB_CORRECTED_8bit.TIF"
    }
  }]
}
EOF
cat -n "${@: -1}"/results_manifest.json
