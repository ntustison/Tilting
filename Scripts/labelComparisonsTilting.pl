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
  Usage: labelComparisonsTilting.pl <inputDir>
 };

my $baseDirectory = '/Users/ntustison/Data/Public/MICCAI-2012-Multi-Atlas-Challenge-Data/';
my $ANTsPath = '/Users/ntustison/Pkg/ANTS/bin/bin/';

my ( $outputDirectory ) = @ARGV;

if( ! -d $outputDirectory )
  {
  mkpath( $outputDirectory, {verbose => 0, mode => 0755} ) or
    die "Can't create output directory $outputDirectory\n\t";
  }

my $overlapMeasures = "${baseDirectory}/overlapMeasuresTilting.csv";

open( FILE, ">${overlapMeasures}" );

my $trainingDirectory = "${baseDirectory}/training-images/";
my $trainingLabelsDirectory = "${baseDirectory}/training-labels/";
my @trainingLabels = <${trainingLabelsDirectory}/*glm.nii.gz>;

my @suffixList = ( ".nii.gz" );

# my @largeLabels = ( 35, 38, 39, 40, 41, 44, 45, 73 );
my @largeLabels = ();

print FILE "PAIR_ID,ANTS,antsRegistration,ANTSAffineOnly,antsRegistrationAffineOnly,ANTSWithOtherAffine\n";
for( my $i = 0; $i < @trainingLabels; $i++ )
  {
  my ( $fixedImagePrefix, $fixedDirectories, $fixedSuffix ) = fileparse( $trainingLabels[$i], @suffixList );
  $fixedImagePrefix =~ s/_glm//;

  for( my $j = 0; $j < @trainingLabels; $j++ )
    {
    if( $i == $j )
      {
      next;
      }

    my ( $movingImagePrefix, $movingDirectories, $movingSuffix ) = fileparse( $trainingLabels[$j], @suffixList );
    $movingImagePrefix =~ s/_glm//;

    print "${fixedImagePrefix}x${movingImagePrefix}\n";

    my @outputPrefix = ();
    my @warpedTrainingLabels = ();

    $outputPrefix[0] = "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}_ANTS_";
    $warpedTrainingLabels[0] = "${outputPrefix[0]}LabelsWarped.nii.gz";

    $outputPrefix[1] = "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}_antsRegistration_";
    $warpedTrainingLabels[1] = "${outputPrefix[1]}LabelsWarped.nii.gz";

    $outputPrefix[2] = "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}_ANTS_Affine";
    $warpedTrainingLabels[2] = "${outputPrefix[2]}LabelsWarped.nii.gz";

    $outputPrefix[3] = "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}_antsRegistration_Affine";
    $warpedTrainingLabels[3] = "${outputPrefix[3]}LabelsWarped.nii.gz";

    $outputPrefix[4] = "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}_ANTS_with_antsRegistrationAffine_";
    $warpedTrainingLabels[4] = "${outputPrefix[4]}LabelsWarped.nii.gz";

    print FILE "${fixedImagePrefix}x${movingImagePrefix},";

    my $tmpLabels = "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}tmpLabels.nii.gz";
    `cp $trainingLabels[$i] $tmpLabels`;

    for( my $k = 0; $k < @warpedTrainingLabels; $k++ )
      {
      my $tmpLabelsWarped = "${outputDirectory}/${fixedImagePrefix}x${movingImagePrefix}tmpLabelsWarped.nii.gz";
      `cp $warpedTrainingLabels[$k] $tmpLabelsWarped`;

      for( my $l = 0; $l < @largeLabels; $l++ )
        {
        if( $k == 0 )
          {
          `UnaryOperateImage 3 $tmpLabels r 0 $tmpLabels $largeLabels[$l] 0`;
          }
        `UnaryOperateImage 3 $tmpLabelsWarped r 0 $tmpLabelsWarped $largeLabels[$l] 0`;
        }

      my @out = `LabelOverlapMeasures 3 $tmpLabelsWarped $tmpLabels`;
      chomp( $out[2] );
      my @measures = split( ' ', $out[2] );

      print FILE "${measures[2]}";
      if( $k == @warpedTrainingLabels - 1 )
        {
        print FILE "\n";
        }
      else
        {
        print FILE ",";
        }
      unlink( $tmpLabelsWarped );
      }
    unlink( $tmpLabels );
    }
  }
close( FILE );
