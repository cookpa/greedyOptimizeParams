#!/bin/bash

if [[ $# -eq 0 ]]; then
  echo "  $0 <subj> <outputBaseDir>"
  exit 1
fi

subj=$1
outputBaseDir=$2

binDir=`dirname $0`

mkdir -p ${outputBaseDir}/$subj

qsub -l h_vmem=8G,s_vmem=8G -cwd -j y -o ${outputBaseDir}/${subj}/${subj}_log.txt -b y -v PATH=/data/grossman/pcook/antsVsGreedyJLF/bin:$PATH ${binDir}/greedyLabelSubjectLOO.pl $subj $outputBaseDir

