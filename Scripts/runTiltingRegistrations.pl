#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use Switch;
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: runTiltingRegistrations.pl <outputDir> <ANTS=0 or antsRegistration=1>
 };

# my ( $baseDirectory, $outputDirectory ) = @ARGV;
my $baseDirectory = '/home/njt4n/share/Data/Public/MICCAI-2012-Multi-Atlas-Challenge-Data/';
my $ANTsPath = '/home/njt4n/share/Pkg/ANTs/bin/bin/';

my ( $outputDirectory, $which ) = @ARGV;

if( ! -d $outputDirectory )
  {
  mkpath( $outputDirectory, {verbose => 0, mode => 0755} ) or
    die "Can't create output directory $outputDirectory\n\t";
  }

my $trainingDirectory = "${baseDirectory}/training-images/";
my $trainingLabelsDirectory = "${baseDirectory}/training-labels/";

my @trainingImages = <${trainingDirectory}/*3.nii.gz>;
my @trainingLabels = <${trainingLabelsDirectory}/*3_glm.nii.gz>;

my @suffixList = ( ".nii.gz" );

my $count = 0;
for( my $i = 0; $i < @trainingImages; $i++ )
  {
  my ( $fixedImagePrefix, $fixedDirectories, $fixedSuffix ) = fileparse( $trainingImages[$i], @suffixList );

  for( my $j = 0; $j < @trainingImages; $j++ )
    {
    if( $i == $j )
      {
      next;
      }

    my ( $movingImagePrefix, $movingDirectories, $movingSuffix ) = fileparse( $trainingImages[$j], @suffixList );

    my $outputPrefix = "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}";
    if( $which == 1 )
      {
      $outputPrefix .= '_antsRegistration_';
      }
    elsif( $which == 0 )
      {
      $outputPrefix .= '_ANTS_';
      }
    elsif( $which == 2 )
      {
      $outputPrefix .= '_ANTS_with_antsRegistrationAffine_';
      }

    my $commandFile = "${outputPrefix}command.sh";

    open( FILE, ">${commandFile}" );
    print FILE "#!/bin/sh\n";
    print FILE "export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1\n";
    print FILE "\n";

    my @regArgs = ();
    my @xfrmArgs = ();

    if( $which == 1 )
      {
      @regArgs = ( "${ANTsPath}/antsRegistration",
                   '-d', 3,
                   '-o', "${outputPrefix}",
                   '-u', 1,
                   '-w', '[0.01,0.99]',
                   '-r', "[${trainingImages[$i]},${trainingImages[$j]},1]",             # align centers of mass
                   '-t', 'Rigid[0.1]',                                                   # rigid stage
                   '-m', "MI[${trainingImages[$i]},${trainingImages[$j]},1,32,Regular,0.25]",
                   '-c', '[1000x500x250x100,1e-8,10]',
                   '-s', '4x2x1x0',
                   '-f', '8x4x2x1',
                   '-t', 'Affine[0.1]',                                                  # affine stage
                   '-m', "MI[${trainingImages[$i]},${trainingImages[$j]},1,32,Regular,0.25]",
                   '-c', '[1000x500x250x100,1e-8,10]',
                   '-s', '4x2x1x0',
                   '-f', '8x4x2x1',
                   '-t', 'SyN[0.1,3,0]',                             # syn stage
                   '-m', "CC[${trainingImages[$i]},${trainingImages[$j]},1,4]",
                   '-c', '[100x100x70x20,1e-9,15]',
                   '-s', '3x2x1x0',
                   '-f', '6x4x2x1'
                );
      print FILE "@regArgs\n\n";

      my @xfrmArgs = ( "${ANTsPath}/antsApplyTransforms",
                     '-d', 3,
                     '-i', $trainingLabels[$j],
                     '-r', $trainingLabels[$i],
                     '-o', "${outputPrefix}LabelsWarped.nii.gz",
                     '-n', 'NearestNeighbor',
                     '-t', "${outputPrefix}1Warp.nii.gz",
                     '-t', "${outputPrefix}0GenericAffine.mat"
                     );
      print FILE "@xfrmArgs\n\n";

      print FILE "rm -f ${outputPrefix}1Warp.nii.gz ${outputPrefix}1InverseWarp.nii.gz";
      }
    elsif( $which == 0 )
      {
      my $fixedTruncated = "${outputDirectory}/${fixedImagePrefix}_truncated.nii.gz";
      my $movingTruncated = "${outputDirectory}/${movingImagePrefix}_truncated.nii.gz";

      print FILE "if [[ ! -f ${fixedTruncated} ]]; then\n";
      print FILE "${ANTsPath}/ImageMath 3 $fixedTruncated TruncateImageIntensity $trainingImages[$i] 0.01 0.99\n";
      print FILE "fi\n";

      print FILE "if [[ ! -f ${movingTruncated} ]]; then\n";
      print FILE "${ANTsPath}/ImageMath 3 $movingTruncated TruncateImageIntensity $trainingImages[$j] 0.01 0.99\n";
      print FILE "fi\n";

      @regArgs = ( "${ANTsPath}/ANTS", 3,
                   '-o', ${outputPrefix},
                   '-m', "CC[${fixedTruncated},${movingTruncated},1,4]",
                   '-t', 'SyN[0.1]',
                   '-r', 'Gauss[3,0]',
                   '-i', '100x100x70x20',
                   '--use-Histogram-Matching'
                );

      print FILE "@regArgs\n\n";

      my @xfrmArgs = ( "${ANTsPath}/antsApplyTransforms",
                     '-d', 3,
                     '-i', $trainingLabels[$j],
                     '-r', $trainingLabels[$i],
                     '-o', "${outputPrefix}LabelsWarped.nii.gz",
                     '-n', 'NearestNeighbor',
                     '-t', "${outputPrefix}Warp.nii.gz",
                     '-t', "${outputPrefix}Affine.txt"
                     );
      print FILE "@xfrmArgs\n\n";

      print FILE "rm -f ${outputPrefix}Warp.nii.gz ${outputPrefix}InverseWarp.nii.gz";
      }
    elsif( $which == 2 )
      {
      my $fixedTruncated = "${outputDirectory}/${fixedImagePrefix}_truncated.nii.gz";
      my $movingTruncated = "${outputDirectory}/${movingImagePrefix}_truncated.nii.gz";

      print FILE "if [[ ! -f ${fixedTruncated} ]]; then\n";
      print FILE "${ANTsPath}/ImageMath 3 $fixedTruncated TruncateImageIntensity $trainingImages[$i] 0.01 0.99\n";
      print FILE "fi\n";

      print FILE "if [[ ! -f ${movingTruncated} ]]; then\n";
      print FILE "${ANTsPath}/ImageMath 3 $movingTruncated TruncateImageIntensity $trainingImages[$j] 0.01 0.99\n";
      print FILE "fi\n";

      @regArgs = ( "${ANTsPath}/ANTS", 3,
                   '-o', ${outputPrefix},
                   '-m', "CC[${fixedTruncated},${movingTruncated},1,4]",
                   '-t', 'SyN[0.1]',
                   '--continue-affine', 'false',
                   '--number-of-affine-iterations', 0,
                   '-a', "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}_antsRegistration_0GenericAffine.txt",
                   '-r', 'Gauss[3,0]',
                   '-i', '100x100x70x20',
                   '--use-Histogram-Matching'
                );

      print FILE "@regArgs\n\n";

      my @xfrmArgs = ( "${ANTsPath}/antsApplyTransforms",
                     '-d', 3,
                     '-i', $trainingLabels[$j],
                     '-r', $trainingLabels[$i],
                     '-o', "${outputPrefix}LabelsWarped.nii.gz",
                     '-n', 'NearestNeighbor',
                     '-t', "${outputPrefix}Warp.nii.gz",
                     '-t', "${outputPrefix}Affine.txt"
                     );
      print FILE "@xfrmArgs\n\n";

      print FILE "rm -f ${outputPrefix}Warp.nii.gz ${outputPrefix}InverseWarp.nii.gz";
      }

    close( FILE );

    if( ! -e "${outputPrefix}LabelsWarped.nii.gz" )
      {
      print "** registration ${outputPrefix}\n";
      $count++;
      if( $which == 0 || $which == 2 )
        {
        system( "qsub -N ${count}_ANTS -q nopreempt -l nodes=1:ppn=1 -l walltime=20:00:00 -l mem=8gb $commandFile" );
        }
      else
        {
        system( "qsub -N ${count}_ants -q nopreempt -l nodes=1:ppn=1 -l walltime=25:00:00 -l mem=20gb $commandFile" );
        }
      }
    else
      {
      print " not doing ${outputPrefix}\n";
      }
   # sleep 15;
    }
  }

print "Running $count command files.\n";
