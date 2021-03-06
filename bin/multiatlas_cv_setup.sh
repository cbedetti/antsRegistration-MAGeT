#!/bin/bash
# Generator for multi-atlas validation of MaGeT, shamelessly stolen from ealier script
# Start by running a mb run with all inputs as atlases, templates and subjects, skip voting
# This primes the pipeline with all the possible registrations
# Then, run multiatlas_setup.sh <nfolds> <natlases> <optional targetdir>
# This shuffles the list of inputs and creates <nfolds> random samples satisftying
# <natlases>
# Afterwards links into the directory the already processed transforms and candidate labels
# Then all that is left is to run mb-multiatlas.sh in each directory to complete the voting stage
set -euo pipefail

nfolds=$1
natlases=$2
pool=(input/atlas/*t1.mnc)

if [[ $3 ]]
then
  targetdir=$3
else
  targetdir=.
fi

for fold in $(seq ${nfolds})
do
  #Shuffle inputs in a random list using sort
  pool=($(printf "%s\n" "${pool[@]}" | sort -R))
  #Since list is now random, slice array according to numbers provided before
  atlases=("${pool[@]:0:${natlases}}")
  templates=("${pool[@]:${natlases}}")

  #Setup folders for random run
  folddir=${targetdir}/NFOLD_multiatlas/${natlases}atlases_fold${fold}
  mkdir -p ${folddir}/input/{atlas,template}
  mkdir -p ${folddir}/output/multiatlas/labels/majorityvote

  #Link in precomputed transforms and candidate labels
  ln -s "$(readlink -f output/transforms)" ${folddir}/output/transforms
  ln -s "$(readlink -f output/multiatlas/labels/candidates)" ${folddir}/output/multiatlas/labels/candidates

  #Do a trick of replacing _t1.mnc with * to allow bash expansion to include all label files
  tmp=("${atlases[@]/_t1.mnc/*}")
  ln -s ${tmp[@]} ${folddir}/input/atlas
  ln -s "${templates[@]}" ${folddir}/input/template
  (cd ${folddir}; mb.sh -- multiatlas-vote)
done

multiatlas_cv_collect.sh ${natlases}atlases_0templates.csv ${natlases}atlases ${targetdir} && rm -rf ${targetdir}/NFOLD_multiatlas/${natlases}atlases_fold*
