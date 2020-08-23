#!/usr/bin/env perl

# Copyright (c) 2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use JSON::PP;

my $help = 0;
my $bench_type = '';
my $input_file = '';
my $output_file = '';
my %output;
$output{'groups'} = ();

GetOptions('help' => \$help,
    'type=s' => \$bench_type,
    'infile=s' => \$input_file,
    'outfile=s' => \$output_file) or pod2usage(-verbose => 1, -exitval => 1);
pod2usage(-verbose => 1, -exitval => 0) if $help;
pod2usage(-msg => 'Missing a benchmark type', -exitval => 1) if $bench_type eq '';
pod2usage(-msg => 'Missing an input file', -exitval => 1) if $input_file eq '';
pod2usage(-msg => 'Missing an output file', -exitval => 1) if $output_file eq '';

my %group = (
    name => $bench_type,
);
$group{'tests'} = ();

open(my $input_handle, '<', $input_file) or die "Unable to open file '$input_file': $!";

if ($bench_type eq 'block_sim') {
    my $start_processing = 0;
    my $validators = 0;
    my $epoch_length = 0;
    while (<$input_handle>) {
        # strip both ends
        s/^\s+|\s+$//;

        $start_processing = 1 if /^Done!$/;
        next if not $start_processing;

        if (/^Validators: (\d+), epoch length: (\d+)$/) {
            ($validators, $epoch_length) = ($1, $2);
        } elsif (/^(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+), (.+)$/) {
            my ($average, $stddev, $min, $max, $samples, $test_name) = ($1, $2, $3, $4, $5, $6);
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
        }
    }
} elsif ($bench_type eq 'state_sim') {
    my $start_processing = 0;
    my $validators = 0;
    my $epoch_length = 0;
    while (<$input_handle>) {
        # strip both ends
        s/^\s+|\s+$//;

        $start_processing = 1 if /^:Done!$/;
        next if not $start_processing;

        if (/^Validators: (\d+), epoch length: (\d+)$/) {
            ($validators, $epoch_length) = ($1, $2);
        } elsif (/^(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+), (.+)$/) {
            my ($average, $stddev, $min, $max, $samples, $test_name) = ($1, $2, $3, $4, $5, $6);
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
        }
    }
} else {
    die "Unknown benchmark type: $bench_type";
}

push (@{$output{'groups'}}, \%group);

open(my $output_handle, '>', $output_file) or die "Unable to open file '$output_file': $!";
my $json_output = JSON::PP->new->utf8->pretty->encode(\%output);
print $output_handle $json_output;
close($output_handle);


__END__

=pod

=head1 NAME

process_benchmark_output.pl

=head1 SYNOPSIS

 process_benchmark_output.pl --type block_sim --infile block_sim_out.txt --outfile results/block_sim/result.json

or

 process_benchmark_output.pl --help

=cut

