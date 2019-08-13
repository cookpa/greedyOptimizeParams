#!/usr/bin/perl -w

use strict;
use File::Path;
use File::Basename;

my $usage = qq{

  $0 subjToLabel outputBaseDir

  Will save deformed images and labels in outputBaseDir/subjToLabel

  Requires c3d, greedy, label_fusion

};


if ($#ARGV < 0) {
  print $usage;
  exit 1;  
}

my ($sysTmpDir) = $ENV{'TMPDIR'};

my $whichGreedy = `which greedy`;

chomp($whichGreedy);

if (! -f "$whichGreedy") {
    print " Can't find greedy \n";
    exit 1;
}

my $greedyPath = dirname($whichGreedy);

my $subjToLabel = $ARGV[0];

my $outputBaseDir = $ARGV[1];


# Directory for temporary files that is deleted later
my $tmpDir = "";

my $tmpDirBaseName = "${subjToLabel}LOOJLF";

my $outputDir = "${outputBaseDir}/$subjToLabel";

if (! -d $outputDir ) { 
  mkpath($outputDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $outputDir\n\t";
}

if ( !($sysTmpDir && -d $sysTmpDir) ) {
    $tmpDir = $outputDir . "/${tmpDirBaseName}";
}
else {
    # Have system tmp dir
    $tmpDir = $sysTmpDir . "/${tmpDirBaseName}";
}

# Gets removed later, so check we can create this and if not, exit immediately
mkpath($tmpDir, {verbose => 0, mode => 0755}) or die "Cannot create working directory $tmpDir (maybe it exists from a previous failed run)\n\t";

my $brainDir="/data/picsl/pcook/oasisLOO/Brains";

my $segDir="/data/picsl/pcook/oasisLOO/Segmentations";

my @subjects = qw/1000 1001 1002 1006 1007 1008 1009 1010 1011 1012 1013 1014 1015 1036 1017 1003 1004 1005 1018 1019 1101 1104 1107 1110 1113 1116 1119 1122 1125 1128/;

my $fixed = "${brainDir}/${subjToLabel}_3.nii.gz";
my $fixedSeg = "${segDir}/${subjToLabel}_3_seg.nii.gz";

my $brainMask = "${tmpDir}/${subjToLabel}BrainMask.nii.gz";
my $regMask = "${tmpDir}/${subjToLabel}RegMask.nii.gz";

# Dilate brain mask by 2 voxels to make JLF mask, so we test edges of the brain
# mask for accuracy
my $jlfMask = "${outputDir}/${subjToLabel}JLFMask.nii.gz";

system("c3d $fixedSeg -thresh 1 Inf 1 0 -o $brainMask -dilate 1 10x10x10vox -o $regMask");
system("c3d $brainMask -dilate 1 2x2x2vox -o $jlfMask");

# Array of deformed atlases and labels to be added to JLF command later
my @allMovingDeformed = ();
my @allMovingSegDeformed = ();

my $greedyBase = "/usr/bin/time -v greedy -d 3 -threads 1";

foreach my $subject (@subjects) {
    
    my $moving = "${brainDir}/${subject}_3.nii.gz";
    my $movingSeg = "${segDir}/${subject}_3_seg.nii.gz";
    
    my $movingDeformed = "${outputDir}/${subject}To${subjToLabel}Deformed.nii.gz";
    my $movingSegDeformed = "${outputDir}/${subject}To${subjToLabel}SegDeformed.nii.gz";
    
    if ($subject != $subjToLabel) { 
	
	if (! -f $movingSegDeformed) {
	    
	    my $comTransform = "${tmpDir}/${subject}To${subjToLabel}COM.mat";
	    
	    my $regCOMCmd = "$greedyBase -moments 1 -o $comTransform -det 1 -i $fixed $moving";
	    
	    print "\n--- Reg COM Call ---\n$regCOMCmd\n---\n";
	    
	    system("$regCOMCmd");
	    
	    my $rigidTransform = "${tmpDir}/${subject}To${subjToLabel}Rigid.mat";
	    
	    my $regRigidCmd = "$greedyBase -a -dof 6 -ia $comTransform -o $rigidTransform -i $fixed $moving -m NCC 4x4x4 -n 20x50x50x0 -gm $regMask";
	    
	    print "\n--- Reg Rigid Call ---\n$regRigidCmd\n---\n";
	    
	    system("$regRigidCmd");
	    
	    my $affineTransform = "${tmpDir}/${subject}To${subjToLabel}Affine.mat";
	    
	    my $regAffineCmd = "$greedyBase -a -dof 12 -ia $rigidTransform -o $affineTransform -i $fixed $moving -m NCC 4x4x4 -n 20x50x50x20 -gm $regMask";
	    
	    print "\n--- Reg Affine Call ---\n$regAffineCmd\n---\n";
	    
	    system("$regAffineCmd");
	    
	    my $deformableTransform = "${tmpDir}/${subject}To${subjToLabel}Warp.nii.gz";
	    
	    my $regDeformableCmd = "$greedyBase -it $affineTransform -o $deformableTransform -i $fixed $moving -m NCC 4x4x4 -n 20x40x80x20 -e 1.0 -wp 0 -gm $regMask";

	    print "\n--- Reg Deformable Call ---\n$regDeformableCmd\n---\n";
	    
	    system("$regDeformableCmd");
	    
	    my $applyTransCmd = "$greedyBase -float -rf $fixed -ri LINEAR -rm $moving $movingDeformed -ri LABEL 0.01mm -rm $movingSeg $movingSegDeformed -r $deformableTransform $affineTransform";
	    
	    print "\n--- Apply transforms Call ---\n$applyTransCmd\n---\n";
	    
	    system("$applyTransCmd");
	    
	}
	
	push(@allMovingDeformed, $movingDeformed);
	push(@allMovingSegDeformed, $movingSegDeformed);
    }	
    
}

	
my $jlfCmd="label_fusion 3 -g " . join(" ", @allMovingDeformed) . " -l " . join(" ", @allMovingSegDeformed) . " -M $jlfMask $fixed ${outputDir}/${subjToLabel}Labels.nii.gz";


print "\n--- JLF Call ---\n$jlfCmd\n---\n";

# Run jlf separately because it requires much more RAM

my $jlfScript = "${outputDir}/greedyJLF${subjToLabel}.sh";

open(my $fh, ">", $jlfScript);

print $fh qq{#!/bin/bash

export PATH=$greedyPath:\$PATH

$jlfCmd
};

close($fh);

system("qsub -S /bin/bash -cwd -j y -o ${outputDir}/${subjToLabel}greedyJLFLog.txt -l h_vmem=10G,s_vmem=10G $jlfScript");

system("rm -f ${tmpDir}/*");
system("rmdir $tmpDir");
