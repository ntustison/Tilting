library( ggplot2 )

stats <- read.csv( "overlapMeasuresTilting.csv", header = TRUE )

plotLabels <- c(
                rep.int( "ANTS", length( stats$ANTS ) ),
                rep.int( "ANTS with other affine", length( stats$ANTSWithOtherAffine ) ),
                rep.int( "antsRegistration", length( stats$antsRegistration ) ),
                rep.int( "Affine ANTS", length( stats$ANTSAffineOnly ) ),
                rep.int( "Affine antsRegistration", length( stats$antsRegistrationAffineOnly ) )
                )

dice <- c( stats$ANTS, stats$ANTSWithOtherAffine, stats$antsRegistration, stats$ANTSAffineOnly, stats$antsRegistrationAffineOnly )

plotData <- data.frame( Type = plotLabels, Dice = dice )

myPlot <- ggplot( plotData,  aes( x = factor( Type ), y = Dice ) ) +
          geom_boxplot( aes( fill = Type ) ) +
          ggtitle( "MICCAI 2012 Multi-Label Atlas Challenge Data" ) +
          theme( legend.position = "none" ) +
          scale_x_discrete( "" )
#           scale_x_discrete( breaks = c( "ANTS", "ANTS with other affine", "antsRegistration", "Affine ANTS", "Affine antsRegistration" ),
#                             labels = c( "ANTS", "ANTS with other affine", "antsRegistration", "Affine ANTS", "Affine antsRegistration" ) )

ggsave( filename = paste( "tilting.pdf", sep = "" ), plot = myPlot, width = 8, height = 5, units = 'in' )

