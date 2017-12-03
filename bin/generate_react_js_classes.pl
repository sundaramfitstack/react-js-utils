#!/usr/bin/env perl
use strict;
use Cwd;
use Data::Dumper;
use Carp;
use Pod::Usage;
use File::Spec;
use File::Path;
use Term::ANSIColor;
use FindBin;
use XML::Simple;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Template;

use lib "$FindBin::Bin/../lib";

use constant TRUE => 1;

use constant FALSE => 0;

use constant DEFAULT_CLASS_TEMPLATE_FILE => './template/react_class_js.tmpl';

use constant DEFAULT_VERBOSE => TRUE;

use constant DEFAULT_INDIR => File::Spec->rel2abs(cwd());

my $login =  getlogin || getpwuid($<) || $ENV{USER} || "sundaramj";

use constant DEFAULT_OUTDIR => '/tmp/' . $login . '/' . File::Basename::basename($0) . '/' . time();

$|=1; ## do not buffer output stream

## Command-line arguments
my (
    $infile, 
    $outdir,
    $help, 
    $man, 
    $verbose,
    $class_template_file
    );

my $results = GetOptions (
    'infile=s'                       => \$infile,
    'help|h'                         => \$help,
    'man|m'                          => \$man,
    'outdir=s'                       => \$outdir,
    'class_template_file=s'          => \$class_template_file,
    );

&checkCommandLineArguments();

my $config_lookup = &get_config_lookup();

&generate_classes($config_lookup);

printGreen(File::Spec->rel2abs($0) . " execution completed\n");

exit(0);

##-----------------------------------------------------------
##
##    END OF MAIN -- SUBROUTINES FOLLOW
##
##-----------------------------------------------------------

sub get_config_lookup {

    my $parser = new XML::Simple();
    if (!defined($parser)){
        confess("Could not instantiate XML::Simple");
    }

    my $lookup = $parser->XMLin($infile);
    if (!defined($lookup)){
        confess("lookup was not defined");
    }

    return $lookup;
}

sub generate_classes {

    my ($config_lookup) = @_;

    print "Going to generate React-JS classes now\n";

    my $ctr = 0;

    foreach my $class_lookup (@{$config_lookup->{question}}){

        $ctr++;

        my $class_name = $class_lookup->{class};

        print "Processing class '$class_name'\n";

        my $question_text = $class_lookup->{text};

        my $vars_lookup = {
            class_name      => $class_name,
            question_text   => $question_text,
            has_some_method => FALSE,
            has_some_text   => FALSE,
            has_some_textarea => FALSE,
            has_some_button => FALSE
        };


        if (exists $class_lookup->{'input-elements'}->{'input-element'}){

            foreach my $input_element_lookup (@{$class_lookup->{'input-elements'}->{'input-element'}}){
            
                my $type;
                my $value;
                my $method;

                my $inputElementLookup = {};

                if (exists $input_element_lookup->{type}){
                    
                    $type = $input_element_lookup->{type};

                }
                else {
                    die "type was not defined for " . Dumper $input_element_lookup;
                }


                if (exists $input_element_lookup->{action}->{method}){

                    $method = $input_element_lookup->{action}->{method};

                    $inputElementLookup->{method} = $method;

                    push(@{$vars_lookup->{bind_method_list}}, $method);

                    $vars_lookup->{'has_some_method'} = TRUE;
                }

                if (exists $input_element_lookup->{value}){

                    $value = $input_element_lookup->{value};

                    $inputElementLookup->{value} = $value;

                    push(@{$vars_lookup->{value_list}}, $value);

                }

                if (exists $input_element_lookup->{placeholder}){

                    $inputElementLookup->{placeholder} = $input_element_lookup->{placeholder};
                }


                if (exists $input_element_lookup->{label}){

                    $inputElementLookup->{label} = $input_element_lookup->{label};
                }

                if (($type eq 'text') || ($type eq 'textbox')){
                    
                    push(@{$vars_lookup->{textbox_list}}, $inputElementLookup);

                    $vars_lookup->{'has_some_text'} = TRUE;

                }
                elsif ($type eq 'textarea'){
                    
                    push(@{$vars_lookup->{textarea_list}}, $inputElementLookup);   

                    $vars_lookup->{'has_some_textarea'} = TRUE;

                }
                elsif ($type eq 'button'){

                    push(@{$vars_lookup->{button_list}}, $inputElementLookup);   

                    $vars_lookup->{'has_some_button'} = TRUE;

                }
            }
        }

        &writeOutfile($class_name, $vars_lookup);
    }

    print "Finished processing '$ctr' records\n";
}

sub writeOutfile {

    my ($class_name, $vars_lookup) = @_;

    my $outfile = $outdir . '/' . $class_name . '.js';

    my $template = new Template({
        ABSOLUTE   => TRUE,
        PRE_CHOMP  => FALSE,
        POST_CHOMP => FALSE
        });
    
    if (!defined($template)){
        confess("Could not instantiate Template");
    }


    $template->process($class_template_file, $vars_lookup, $outfile,  { binmode => ':utf8' }) || die $template->error();

    print "Wrote React-JS class file '$outfile'\n";
}

sub checkCommandLineArguments {
   
    if ($man){
    	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }
    
    if ($help){
    	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }

    my $fatalCtr=0;

    if (!defined($infile)){

        $fatalCtr++;
            
        printBoldRed("--infile was not specified");
    }
    else {
        $infile = File::Spec->rel2abs($infile);

        &checkInfileStatus($infile);
    }

    if (!defined($verbose)){

        $verbose = DEFAULT_VERBOSE;

        printYellow("--verbose was not specified and therefore was set to default '$verbose'");
    }

    if (!defined($class_template_file)){

        $class_template_file = DEFAULT_CLASS_TEMPLATE_FILE;

        printYellow("--class_template_file was not specified and therefore was set to default '$class_template_file'");
    }

    &checkInfileStatus($class_template_file);

    $class_template_file = File::Spec->rel2abs($class_template_file);

    if (!defined($outdir)){

        $outdir = DEFAULT_OUTDIR;

        printYellow("--outdir was not specified and therefore was set to default '$outdir'");
    }

    $outdir = File::Spec->rel2abs($outdir);

    if (!-e $outdir){

        mkpath ($outdir) || die "Could not create output directory '$outdir' : $!";

        printYellow("Created output directory '$outdir'");

    }
    

    if ($fatalCtr> 0 ){
    	die "Required command-line arguments were not specified\n";
    }
}

sub printBoldRed {

    my ($msg) = @_;
    print color 'bold red';
    print $msg . "\n";
    print color 'reset';
}

sub printYellow {

    my ($msg) = @_;
    print color 'yellow';
    print $msg . "\n";
    print color 'reset';
}

sub printGreen {

    my ($msg) = @_;
    print color 'green';
    print $msg . "\n";
    print color 'reset';
}


sub checkOutdirStatus {

    my ($outdir) = @_;

    if (!-e $outdir){
        
        mkpath($outdir) || die "Could not create output directory '$outdir' : $!";
        
        printYellow("Created output directory '$outdir'");
    }
    
    if (!-d $outdir){

        printBoldRed("'$outdir' is not a regular directory\n");
    }
}


sub checkInfileStatus {

    my ($infile) = @_;

    if (!defined($infile)){
        die ("infile was not defined");
    }

    my $errorCtr = 0 ;

    if (!-e $infile){

        printBoldRed("input file '$infile' does not exist");

        $errorCtr++;
    }
    else {

        if (!-f $infile){

            printBoldRed("'$infile' is not a regular file");

            $errorCtr++;
        }

        if (!-r $infile){

            printBoldRed("input file '$infile' does not have read permissions");

            $errorCtr++;
        }
        
        if (!-s $infile){

            printBoldRed("input file '$infile' does not have any content");

            $errorCtr++;
        }
    }
     
    if ($errorCtr > 0){

        printBoldRed("Encountered issues with input file '$infile'");

        exit(1);
    }
}




__END__

=head1 NAME

 generate_react_js_classes.pl - Perl script to generate React JS classes


=head1 SYNOPSIS

 perl util/generate_react_js_classes.pl

=head1 OPTIONS

=over 8

=item B<--infile>


=item B<--outdir>


=back

=head1 DESCRIPTION

 A script for generating React JS classes.

=head1 CONTACT

 Jay Sundaram 

 Copyright Jay Sundaram

 Can be distributed under GNU General Public License terms

=cut