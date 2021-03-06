#!/bin/bash -x

if [ $# -ne 1 ] && [ "$2" != "-no_cal" ]; then
   echo "Pipeline to process Arecibo data of FRB121102 on DOP263."
   echo "The pipeline uses pulses stored in a HDF5 database to chop raw data around the pulses."
   echo ""
   echo "Usage: bash chop_raw_data.sh OBS_ID"
   echo "NB: use the command bash to run the pipeline"
   echo "-no_cal option can be used to ignore calibration file."
   exit
fi

#Check that bash is used
if [ ! "$BASH_VERSION" ] ; then
    echo "Execute the script using the bash command. Exiting..."
    exit 1
fi

echo "Pipeline chop_raw_data.sh starting..."
date

#Setting variables
SUB_DIR="/exports/data/puppi/FRB121102_processing/subbanded_data"
GENERAL_OUT_DIR="/exports/data/puppi/FRB121102_processing/pipeline_products"
RAW_DIR="/exports/data/puppi/FRB121102_processing/raw_data"
#PAR_FILE="/psr_archive/hessels/hessels/AO-FRB/pipeline_products/0531+33.par"
SCRIPT_DIR="$( cd -P "$( dirname "$0" )" && pwd )/src"
OBS_ID="$1"
OUT_DIR="$GENERAL_OUT_DIR/$OBS_ID"
DB_FILE="$OBS_ID.hdf5"
CAL_FILE="${OBS_ID:0: -4}`printf "%04d" $((10#${OBS_ID: -4} - 1))`_cal_0001.fits"
FITS_NAME="${OBS_ID}_subs_0001.fits"

#Check that database exists
if [ ! -e $OUT_DIR/pulses/$DB_FILE ]; then
  echo ""
  echo "ATTENTION! HDF5 database $DB_FILE not found. Exiting..."
  exit 1
fi
#Check that the calibration file exists
if [ ! -e $RAW_DIR/$CAL_FILE ]; then
  echo ""
  echo "ATTENTION! Calibration file $CAL_FILE not found."
  if [ "$2" == "-no_cal" ]; then
    echo "-no_cal option detected. Processing will continue."
    echo ""
  else
    echo "Exiting..."
    exit 1
  fi
fi
#Check that subbanded fits file exists
if [ ! -e $SUB_DIR/$FITS_NAME ]; then
  echo ""
  echo "ATTENTION! Subbanded fits file $FITS_NAME not found. Exiting..."
  exit 1
fi

#Copy subbanded file and calibrator
echo "Copying subbanded and calibrator fits files..."
SECONDS=0
if [ ! -e $OUT_DIR/obs_data/$CAL_FILE ]; then
  cp $RAW_DIR/$CAL_FILE $OUT_DIR/obs_data
fi
if [ ! -e $OUT_DIR/obs_data/$FITS_NAME ]; then
  cp $SUB_DIR/$FITS_NAME $OUT_DIR/obs_data
fi
duration=$SECONDS
echo "Subbanded and calibrator fits files copied. Time taken: $(($duration / 60)) m"

#Create raw fits files
echo "Raw fits files and diagnostic plots creating..."
SECONDS=0
if [ ! -e $OUT_DIR/pulses/RFI_pulses ]; then
  mkdir $OUT_DIR/pulses/RFI_pulses
else
  mv $OUT_DIR/pulses/RFI_pulses/* $OUT_DIR/pulses/
fi
#Move RFI pulses in RFI folder
for PULS in `awk -F"\t" '$2 == "2" { print $1"\t"$3 }' $OUT_DIR/pulses/${OBS_ID}_pulses.txt`; do
  mv $OUT_DIR/pulses/$PULS $OUT_DIR/pulses/RFI_pulses/
done
python ${SCRIPT_DIR}/pulses_extract.py -db_name $DB_FILE -pulses_database -pulses_checked ${OUT_DIR}/pulses/${OBS_ID}_pulses.txt \
  -store_dir $OUT_DIR/pulses -extract_raw $RAW_DIR/$OBS_ID -plot_statistics 
duration=$SECONDS
echo "Raw fits files and diagnostic plots created. Time taken: $(($duration / 60)) m"

#Create RFI masks
# echo ".mask files creating..."
# SECONDS=0
# cd $OUT_DIR/pulses
# for puls in `ls -d [0-9]*/`; do 
#   cd $puls
#   for fits in `ls *.fits`; do 
#     rfifind -blocks 10 -noweights -noscales -nooffsets -o ${fits%.fits} $fits
#   done
#   cd $OBS_ID/pulses
# done
# duration=$SECONDS
# echo ".mask files created. Time taken: $(($duration / 60)) m"

#Create psrarchive files
echo "PSRARCHIVE files creating..."
SECONDS=0
python ${SCRIPT_DIR}/create_psrchives.py $OUT_DIR/pulses/$DB_FILE -fits_file "${OBS_ID}_*.fits" -obsPATH $OUT_DIR/pulses
duration=$SECONDS
echo "PSRARCHIVE files created. Time taken: $(($duration / 60)) m"

date
echo "Pipeline chop_raw.sh finished"
