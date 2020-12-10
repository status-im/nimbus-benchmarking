#!/usr/bin/env perl

# Copyright (c) 2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

use strict;
use warnings 'all';
use Getopt::Long;
use Pod::Usage;
use JSON::PP;
use Time::Piece;

# Welcome to the world of insanely fast and unreadable code!
#
# By the time you're done reading this file, you're guaranteed to stop worrying
# and love references, sigils, streamlined regex operators and dynamic typing.
#
# Hey, did you know Perl hashes can only have scalar values? Also, you'll never
# guess what inspired PHP...

my $help = 0;
my $bench_type = '';
my $output_type = 'jenkins';
my $input_file = '';
my $output_file = '';
my $output_dir = '';
my %output_jenkins;
$output_jenkins{'groups'} = ();
my %output_d3;
my $timestr = gmtime()->strftime('%Y-%m-%d-%H:%M:%S');

# Surprisingly elegant option parsing.
# The help text is at the bottom of the file, though, to keep things weird.
GetOptions('help' => \$help,
    'type=s' => \$bench_type,
    'output-type=s' => \$output_type,
    'infile=s' => \$input_file,
    'outfile=s' => \$output_file,
    'outdir=s' => \$output_dir) or pod2usage(-verbose => 1, -exitval => 1);
pod2usage(-verbose => 1, -exitval => 0) if $help;
pod2usage(-msg => 'Missing a benchmark type', -exitval => 1) if $bench_type eq '';
pod2usage(-msg => 'Missing an output type', -exitval => 1) if ($output_type ne 'jenkins' && $output_type ne 'd3');
pod2usage(-msg => 'Missing an input file', -exitval => 1) if $input_file eq '';
pod2usage(-msg => 'Missing an output file', -exitval => 1) if ($output_type eq 'jenkins' && $output_file eq '');
pod2usage(-msg => 'Missing an output dir', -exitval => 1) if ($output_type eq 'd3' && $output_dir eq '');

my %group = (
    name => $bench_type,
);
$group{'tests'} = ();

open(my $input_handle, '<', $input_file) or die "Unable to open file '$input_file': $!";

# Different benchmark groups have different output formats we need to parse.
if ($bench_type eq 'block_sim') {
    my $start_processing = 0;
    my $validators = 0;
    my $epoch_length = 0;
    while (<$input_handle>) {
        # Strip both ends. Aren't hidden loop variables and default operator
        # arguments great?
        s/^\s+|\s+$//;

        $start_processing = 1 if /^Done!$/;
        next if not $start_processing;

        if (/^Validators: (\d+), epoch length: (\d+)$/) {
            ($validators, $epoch_length) = ($1, $2);
        } elsif (/^(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+), (.+)$/) {
            my ($average, $stddev, $min, $max, $samples, $test_name) = ($1, $2, $3, $4, $5, $6);
            # TODO: extract the common parsing part in a subroutine.

            # Jenkins
            my %test = (
                name => $test_name,
            );
            # This particular line noise works. That's all you need to know.
            @{$test{'parameters'}} = (
                {
                    name => 'validators',
                    value => $validators * 1,
                },
                {
                    name => 'epoch length',
                    value => $epoch_length * 1,
                },
            );
            @{$test{'results'}} = (
                {
                    name => 'average',
                    value => $average * 1,
                },
            );
            # Hash references are a great way to confuse readers.
            push(@{$group{'tests'}}, \%test);
            # D3
            # Guess how we converts strings to floats!
            $output_d3{$test_name} = {
                average => $average * 1,
                stddev => $stddev * 1,
            };
        }
    }
} elsif ($bench_type eq 'state_sim') {
    my $start_processing = 0;
    my $validators = 0;
    my $epoch_length = 0;
    while (<$input_handle>) {
        # Strip both ends.
        s/^\s+|\s+$//;

        $start_processing = 1 if /^:Done!$/;
        next if not $start_processing;

        if (/^Validators: (\d+), epoch length: (\d+)$/) {
            ($validators, $epoch_length) = ($1, $2);
        } elsif (/^(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+), (.+)$/) {
            my ($average, $stddev, $min, $max, $samples, $test_name) = ($1, $2, $3, $4, $5, $6);
            # Jenkins
            my %test = (
                name => $test_name,
            );
            @{$test{'parameters'}} = (
                {
                    name => 'validators',
                    value => $validators * 1,
                },
                {
                    name => 'epoch length',
                    value => $epoch_length * 1,
                },
            );
            @{$test{'results'}} = (
                {
                    name => 'average',
                    value => $average * 1,
                },
            );
            push(@{$group{'tests'}}, \%test);
            # D3
            $output_d3{$test_name} = {
                average => $average * 1,
                stddev => $stddev * 1,
            };
        }
    }
} else {
    die "Unknown benchmark type: $bench_type";
}

push (@{$output_jenkins{'groups'}}, \%group);

# We don't want to depend on modules not shipped by default.
my $json = JSON::PP->new->utf8;
if ($output_type eq 'jenkins') {
    open(my $output_handle, '>', $output_file) or die "Unable to open file '$output_file': $!";
    print $output_handle $json->pretty->encode(\%output_jenkins);
    close($output_handle);
} elsif ($output_type eq 'd3') {
    my @benchmarks;
    $output_file = $output_dir . '/' . $bench_type . '_d3.js';

    if (-e $output_file) {
        # Append the new data to an existing file. Who needs backups?
        open(my $output_handle, '<:encoding(UTF-8)', $output_file) or die "Unable to open file '$output_file': $!";
        my $old_benchmarks_text;
        # Ugly trick to read the entire file content in one go.
        { local $/ = undef; $old_benchmarks_text = <$output_handle>; }
        # This JS head and tail should probably be moved to variables.
        # We're never going to have unquoted single quotes inside our JSON data, right?
        $old_benchmarks_text =~ s/^var jsonData = '(.*)';$/$1/;
        # Let the users handle the errors, since it's probably their fault anyway.
        @benchmarks = @{$json->decode($old_benchmarks_text)};
        close($output_handle);
    }

    # Don't worry, we'll process this further in JavaScript.
    push(@benchmarks, {
            'timestamp' => $timestr,
            'data' => \%output_d3,
    });

    open(my $output_handle, '>', $output_file) or die "Unable to open file '$output_file': $!";
    # No pretty printing here. We want one big JSON string to shove into a JS var.
    print $output_handle "var jsonData = '" . $json->encode(\@benchmarks) . "';";
    close($output_handle);
}


__END__

=pod

=head1 NAME

process_benchmark_output.pl

=head1 SYNOPSIS

For a Jenkins benchmark plugin:

 process_benchmark_output.pl --type block_sim --infile block_sim_out.txt --outfile results/block_sim/result.json

For a "d3.js" visualisation:

 process_benchmark_output.pl --type block_sim --output-type d3 --infile block_sim_out.txt --outdir benchmark_results

or

 process_benchmark_output.pl --help

=cut

