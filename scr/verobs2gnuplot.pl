#!/usr/bin/perl
#
#
# Create gnuplot plots from verobs .txt files
#
# Usage: verobs2gnuplot.pl *.txt, where *.txt is the textfiles produced by verobs
#

if ( $ARGV[0] eq '-d' ) {

 print" Scanning $ENV{PWD} for *.txt files \n";

 # Read file from the current directory
 opendir MYDIR, "." ;
 @FILES = grep !/^\.\.?/, readdir MYDIR ;
 @FILES = grep /\.txt$/, @FILES ;
 close MYDIR ;

} else { @FILES = @ARGV } ;


SCAN_INPUT: foreach $input_file (@FILES) {

    print "Process:$input_file \n";

    @col_def   = ();
    @heading   = ();
    @sfile     = ();
    @sint      = ();
    @sintu     = ();

    $col_count = 0 ;

    # Examine file name

    @tmp    = split( '_', $input_file );
    $prefix = shift(@tmp);
    @tmp    = split( '.txt', $input_file );

    # PS or PNG as output
    if ( $ENV{OUTPUT_TYPE} eq 1 ) {
        $output_file = shift(@tmp) . ".ps";
        $terminal    = "set terminal postscript landscape enhanced colour";
    }
    else {
        $output_file = shift(@tmp) . ".1.png";
        $terminal    = "set terminal png";
    }

    open FILE, "< $input_file";

    SCAN_FILE: while (<FILE>) {

        #  
        # Scan through the file and extract the necessary information
        #  

        chomp;

        if ( $_ =~ /#END/ )  { last SCAN_FILE; }

        if ( $_ =~ /#HEADING/ ) {
            @heading = (@heading,substr( $_, 11 ));
            next SCAN_FILE;
        }

        if ( $_ =~ /#AREA/ )   { $area = substr( $_, 5 ); next SCAN_FILE; }
        if ( $_ =~ /#NEXP/ )   { $nexp = substr( $_, 5 ); next SCAN_FILE; }
        if ( $_ =~ /#YLABEL/ ) { $ylabel = substr( $_, 8 ); next SCAN_FILE; }
        if ( $_ =~ /#XLABEL/ ) { $xlabel = substr( $_, 8 ); next SCAN_FILE; }
        if ( $_ =~ /#XMIN/   ) { @tmp = split (' ',$_ ) ; $xmin   = $tmp[1]; next SCAN_FILE; }
        if ( $_ =~ /#XMAX/   ) { @tmp = split (' ',$_ ) ; $xmax   = $tmp[1]; next SCAN_FILE; }
        if ( $_ =~ /#YMIN/   ) { @tmp = split (' ',$_ ) ; $ymin   = $tmp[1]; next SCAN_FILE; }
        if ( $_ =~ /#YMAX/   ) { @tmp = split (' ',$_ ) ; $ymax   = $tmp[1]; next SCAN_FILE; }
        if ( $_ =~ /#MISSING/ ) {
            $missing = substr( $_, 10 );
            $missing =~ s/^\s+//;
            $missing =~ s/\s+$//;
            next SCAN_FILE;
        }

        if ( $_ =~ /#COLUMN/ ) {
            $col_count++ ;
            @col_def = (@col_def,
                       { LEGEND => substr( $_, 11 ) , 
                         COLUMN => substr( $_, 8, 3 ),
                         PT     => 7,
                         LT     => $col_count,
                        },
            ) ;
            next SCAN_FILE;
        }

        if ( $_ =~ /#SLEVEL/ ) {
            @tmp = split( ' ', $_ );
            @sfile = ( @sfile, $tmp[1] );
            @sint  = ( @sint,  $tmp[2] );
            @sintu = ( @sintu, $tmp[3] );
            next SCAN_FILE;
        }
    }

    close FILE;

    #
    # Set plot colors and symbols depending on type of plot
    #

    my $ii = scalar (@col_def);
    unless ( $ii eq 0 ) {
       $ncol = 0;
       if ( $col_def[$ii-2]{LEGEND} ne OBS ) { $ncol = ( $ii -1 ) / $nexp ; } ;
     
       for (my $i=0; $i < $ii; $i++) {
          if ( $col_def[$i]{LEGEND} =~/RMSE/ ) {  $col_def[$i]{PT} = 7 } ;
          if ( $col_def[$i]{LEGEND} =~/BIAS/ ) {  $col_def[$i]{PT} = 4 } ;
          if ( $col_def[$i]{LEGEND} =~/STDV/ ) {  $col_def[$i]{PT} = 3 } ;
   
          if ( $nexp ne 0 ) { $col_def[$i]{LT} = 1 + $i % $nexp ; } ;
   
         if ( $col_def[$i]{LEGEND} eq 'CASES' ) {  $col_def[$i]{LT} = 0 } ;
   
       } ;
    } ;

    # Set colors for map and scatter plots
    @map_colors =  ("7","3","5","6","8","4");
    @scat_colors = ("3","5","2","6","8","1","4","9","7");

    #
    # Start writing the plotting file
    #

    # Print the header
    &header;

    # File type dependent options

    PLOT_TYPES: {

        if ( $prefix =~ /ps/ || $prefix =~ /PS/ ) {
            &timeserie;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /v/ || $prefix =~ /V/ ) {
            &gen_stat;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /l/ || $prefix =~ /L/ ) {
            &plot_vert;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /f/ || $prefix =~ /F/ ) {
            &plot_freq;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /s/ || $prefix =~ /S/ || $prefix =~ /x/ || $prefix =~ /X/ ) {
            $xrange="[$xmin:$xmax]";
            $yrange="[$ymin:$ymax]";
            &plot_scat;
            last PLOT_TYPES;
        }
        if ( $prefix =~ /m/ || $prefix =~ /M/ ) {
            &plot_map;
            last PLOT_TYPES;
        }

        print "Skip unknown file : $input_file \n";
        close GP;
        next SCAN_INPUT;

    }

    # Call gnuplot

    print GP "$plot";
    close GP;
    system("gnuplot plot.gp");

    print "Created:$output_file \n";

}
#################################################################
#################################################################
#################################################################
sub plot_command {

    $plot = "plot ";

    $i = -1;
    foreach (@col_def) {
        $i++;
        if ( $i gt 0 ) { $plot = "$plot,"; }
        $plot = $plot . " '$input_file' using 1:" . $col_def[$i]{COLUMN};
        if ( $col_def[$i]{LEGEND} =~ /CASES/ ) {
          $plot = $plot . " title '$col_def[$i]{LEGEND}' with linespoints lt 0 lw 2 axis x1y2 ";
        } else {
          $plot = $plot . " title '$col_def[$i]{LEGEND}' with linespoints lt $col_def[$i]{LT} lw 2 pt $col_def[$i]{PT}";
	}
    }

}
#################################################################
#################################################################
#################################################################
sub header {

    # Create header
    $len_head = scalar(@heading) ;
    $heading =$heading[0];
    for ($i=1;$i<$len_head;$i++ ) { $heading=$heading."\\n $heading[$i]"; } ;

    open GP, ">plot.gp";

    print GP <<EOF;
$terminal
set output '$output_file'
set missing "$missing"
set title "$heading"

set xlabel "$xlabel"
set ylabel "$ylabel"
set timefmt "%Y%m%d %H"
set grid
EOF
}
#################################################################
#################################################################
#################################################################
sub timeserie {

    print GP <<EOF;
set y2range [0:]
set y2label "No cases"
set y2tics 0,1000
set xdata time
set format x "%d/%m\\n%H"
EOF

    &plot_command ;

}
#################################################################
#################################################################
#################################################################
sub gen_stat {

    print GP <<EOF;
set y2range [0:]
set y2label "No cases"
set y2tics 0,1000
EOF

    &plot_command ;

}
#################################################################
#################################################################
#################################################################
sub plot_vert {

    print GP <<EOF;
set yrange [10:1000] reverse
set x2range [0:]
set x2label "No cases"
set x2tics 0,300
EOF
    $plot = "plot ";

    $i = -1;
    foreach (@col_def) {
        $i++;
        if ( $i gt 0 ) { $plot = "$plot,"; }
        $plot = $plot . " '$input_file' using " . $col_def[$i]{COLUMN} . ":1";
        if ( $col_def[$i]{LEGEND} =~ /CASES/ ) {
          $plot = $plot . " title '$col_def[$i]{LEGEND}' with linespoints lt 0 lw 2 axis x2y1 ";
        } else {
          $plot = $plot . " title '$col_def[$i]{LEGEND}' with linespoints lt $col_def[$i]{LT} lw 2 pt $col_def[$i]{PT}";
	}
    }

}
#################################################################
#################################################################
#################################################################
sub plot_freq {
    &plot_command ;
EOF
}
#################################################################
#################################################################
#################################################################
sub plot_scat {
  
print GP <<EOF;
set key outside 
EOF
    $plot = "plot $xrange$yrange";

    $i = -1;
    foreach (@sfile) {
        $i++;
        if ( $i gt 0 ) { $plot = "$plot,"; }
        if ( $i <= 8 ) { $color_id = $i; } else { $color_id = 8; } ;
        $plot = $plot . " '$input_file"."_".$_."' title '$sint[$i]' lt $scat_colors[$color_id] ps 1 pt 7";
    }

    if ( $prefix =~ /s/ || $prefix =~ /S/ ) { $plot = $plot . ", x notitle with lines lt -1"; } ;

}
#################################################################
#################################################################
#################################################################
sub plot_map {
  
print GP <<EOF;
set key outside 
EOF
    $plot = "plot ".$area." 'coast.dat' notit with lines lt -1,";
    $i = -1;
    foreach (@sfile) {
        $i++;
        if ( $i gt 0 ) { $plot = "$plot,"; }
        $plot = $plot . " '$input_file"."_".$_."' title '$sint[$i] $sintu[$i]' lt $map_colors[$i] ps 1 pt 7";
    }
}
