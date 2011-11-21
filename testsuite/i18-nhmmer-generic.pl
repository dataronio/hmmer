#! /usr/bin/perl

# Test of hmmbuild/nhmmer as used to build a DNA model, then query a  
# a database of long (1MB).
#
# Usage:   ./i18-nhmmer-generic.pl <builddir> <srcdir> <tmpfile prefix>
# Example: ./i18-nhmmer-generic.pl ..         ..       tmpfoo
#
# TJW, Fri Nov 12 11:07:31 EST 2010 [Janelia]
# SVN $URL$
# SVN $Id$

BEGIN {
    $builddir  = shift;
    $srcdir    = shift;
    $tmppfx    = shift;
}

$verbose = 0;

# The test makes use of the following file:
#
# 3box.sto              <msafile>  Single 3box alignment

# It creates the following files:
# $tmppfx.hmm           <hmm>     1 model, 3box
# $tmppfx.A             <seqfile> 1 random seq, ~4.5MB in length
# $tmppfx.B             <seqfile> 2 random seqs, generated by hmmemit from $tmppfx.hmm 
# $tmppfx.fa            <seqdb>   Roughly 4.5MB of a single pseudochromosome, consisting of the two sequences from $tmppfx.B inserted into the sequence of $tmppfx.A  

# All models assumed to be in testsuite subdirectory.
$alignment   = "3box.sto";

@h3progs =  ( "hmmemit", "hmmbuild", "nhmmer");
@eslprogs =  ("esl-shuffle");

# Verify that we have all the executables and datafiles we need for the test.
foreach $h3prog  (@h3progs)  { if (! -x "$builddir/src/$h3prog")              { die "FAIL: didn't find $h3prog executable in $builddir/src\n";              } }
foreach $eslprog (@eslprogs) { if (! -x "$builddir/easel/miniapps/$eslprog")  { die "FAIL: didn't find $eslprog executable in $builddir/easel/miniapps\n";  } }

if (! -r "$srcdir/testsuite/$alignment")  { die "FAIL: can't read msa $alignment in $srcdir/testsuite\n"; }

# Create the test hmm
$cmd = "$builddir/src/hmmbuild $tmppfx.hmm $srcdir/testsuite/$alignment";
$output = do_cmd($cmd);
if ($? != 0) { die "FAIL: hmmbuild failed unexpectedly\n"; } 
if ($output !~ /1     3box                    22    22    20    75    22.00  1.415/) {
	die "FAIL: hmmbuild failed to build correctly\n";
}
$output = do_cmd( "grep MAXL $tmppfx.hmm" );
if ($output !~ /MAXL  75/) {
    die "FAIL: hmmbuild failed to build correctly\n";
}


# Create a roughly 4.5MB database against which to search
$database   = "$tmppfx.fa";
do_cmd ( "$builddir/easel/miniapps/esl-shuffle --seed 1 --dna -G -N 1 -L 4500000 -o $tmppfx.A" );
do_cmd ( "$builddir/src/hmmemit -N 2 --seed 4 -o $tmppfx.B $tmppfx.hmm" ); 
do_cmd ( "head -n 33000 $tmppfx.A > $database" );
do_cmd ( "head -2 $tmppfx.B | tail -1 >> $database" );
do_cmd ( "head -n 55000 $tmppfx.A | tail -22000 >> $database");
do_cmd ( "tail -1 $tmppfx.B >> $database" );
do_cmd ( "tail -20000 $tmppfx.A >> $database" );

# perform nhmmer search
$cmd = "$builddir/src/nhmmer --tformat fasta $tmppfx.hmm $database";
$output = do_cmd($cmd);

if ($? != 0) { die "FAIL: nhmmer failed unexpectedly\n"; }
$expect = q[
Target sequences:                  1  \(8999958 residues\)
Windows passing MSV filter:              1038  \(0.01746\); expected \(0.02\)
Windows passing bias filter:              932  \(0.01568\); expected \(0.02\)
Windows passing Vit filter:                39  \(0.0006548\); expected \(0.001\)
Windows passing Fwd filter:                 2  \(3.311e-05\); expected \(1e-05\)
Total hits:                                 2  \(4.222e-06\)];
if ($output !~ /$expect/s) {
    die "FAIL: nhmmer failed search test 1\n";
}
$expect = 
     q[0.077   15.9   0.2  random   3299961 3299978 
      0.093   15.7   0.6  random   1979941 1979960]; 
if ($output !~ /$expect/s) {
    die "FAIL: nhmmer failed search test 2\n";
}

$cmd = "$builddir/src/nhmmer --tformat fasta --single $tmppfx.hmm $database";
$output = do_cmd($cmd);
if ($? != 0) { die "FAIL: nhmmer failed unexpectedly\n"; }
$expect = q[Target sequences:                  1  \(4499979 residues\)
Windows passing MSV filter:               528  \(0.01771\); expected \(0.02\)
Windows passing bias filter:              477  \(0.01601\); expected \(0.02\)
Windows passing Vit filter:                24  \(0.0007947\); expected \(0.001\)
Windows passing Fwd filter:                 2  \(6.622e-05\); expected \(1e-05\)
Total hits:                                 2  \(8.444e-06\)];

if ($output !~ /$expect/s) {
    die "FAIL: nhmmer failed search test 3\n";
}
$expect = 
    q[0.038   15.9   0.2  random   3299961 3299978 
      0.046   15.7   0.6  random   1979941 1979960 ]; 
if ($output !~ /$expect/s) {
    die "FAIL: nhmmer failed search test 4\n";
}

print "ok\n";
unlink "$tmppfx.hmm";
unlink "$tmppfx.A";
unlink "$tmppfx.B";
unlink "$tmppfx.fa";

exit 0;


sub do_cmd {
    $cmd = shift;
    print "$cmd\n" if $verbose;
    return `$cmd`;	
}
