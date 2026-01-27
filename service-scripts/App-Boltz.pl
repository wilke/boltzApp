#!/usr/bin/env perl

=head1 NAME

App-Boltz - BV-BRC AppService script for Boltz biomolecular structure prediction

=head1 SYNOPSIS

    App-Boltz [--preflight] params.json

=head1 DESCRIPTION

This script implements the BV-BRC AppService interface for running Boltz
biomolecular structure predictions. It handles:

- Input validation and format detection (YAML/FASTA)
- Workspace file download/upload
- Resource estimation for job scheduling
- Execution of boltz predict command
- Result collection and workspace upload

=cut

use strict;
use warnings;
use Carp::Always;  # Stack traces on errors (production debugging)
use Data::Dumper;
use File::Basename;
use File::Path qw(make_path);
use File::Slurp;
use File::Copy;
use JSON;
use Getopt::Long;
use Try::Tiny;

# BV-BRC modules
use Bio::KBase::AppService::AppScript;

# Default log level for production
$ENV{P3_LOG_LEVEL} //= 'INFO';

# Initialize the AppScript with our callbacks
my $script = Bio::KBase::AppService::AppScript->new(\&run_boltz, \&preflight);
$script->run(\@ARGV);

=head2 preflight

Estimate resource requirements based on input parameters.

=cut

sub preflight {
    my ($app, $app_def, $raw_params, $params) = @_;

    # Default resource estimates for GPU-based structure prediction
    my $cpu = 8;
    my $memory = "64G";
    my $runtime = 7200;  # 2 hours default
    my $storage = "50G";

    # Adjust based on parameters
    my $diffusion_samples = $params->{diffusion_samples} // 1;
    my $recycling_steps = $params->{recycling_steps} // 3;

    # More samples = more time and memory
    if ($diffusion_samples > 5) {
        $runtime = 14400;  # 4 hours
        $memory = "96G";
    } elsif ($diffusion_samples > 1) {
        $runtime = 10800;  # 3 hours
        $memory = "80G";
    }

    # More recycling steps = more time
    if ($recycling_steps > 5) {
        $runtime += 3600;
    }

    # Check if affinity prediction is enabled (requires more resources)
    if ($params->{predict_affinity}) {
        $memory = "96G";
        $runtime += 1800;
    }

    return {
        cpu => $cpu,
        memory => $memory,
        runtime => $runtime,
        storage => $storage,
        policy_data => {
            gpu_count => 1,
            partition => 'gpu2',
            constraint => 'A100|H100|H200'
        }
    };
}

=head2 run_boltz

Main execution function for Boltz structure prediction.

=cut

sub run_boltz {
    my ($app, $app_def, $raw_params, $params) = @_;

    print "Starting Boltz structure prediction\n";
    print STDERR "Parameters: " . Dumper($params) . "\n" if $ENV{P3_DEBUG};

    # Create working directories
    my $work_dir = $ENV{P3_WORKDIR} // $ENV{TMPDIR} // "/tmp";
    my $input_dir = "$work_dir/input";
    my $output_dir = "$work_dir/output";

    make_path($input_dir, $output_dir);

    # Download input file from workspace
    my $input_file = $params->{input_file};
    die "Input file is required\n" unless $input_file;

    print "Downloading input file: $input_file\n";
    my $local_input = download_workspace_file($app, $input_file, $input_dir);

    # Detect input format
    my $input_format = detect_input_format($local_input, $params->{input_format});
    print "Detected input format: $input_format\n";

    # Find boltz binary: check PATH first, then P3_BOLTZ_PATH, then default
    my $boltz_bin = find_boltz_binary();
    print "Using boltz binary: $boltz_bin\n";

    # Build boltz command
    my @cmd = ($boltz_bin, "predict", $local_input);

    # Output directory
    push @cmd, "--out_dir", $output_dir;

    # MSA server option
    if ($params->{use_msa_server} // 1) {
        push @cmd, "--use_msa_server";
    }

    # Diffusion samples
    if (my $samples = $params->{diffusion_samples}) {
        push @cmd, "--diffusion_samples", $samples;
    }

    # Recycling steps
    if (my $steps = $params->{recycling_steps}) {
        push @cmd, "--recycling_steps", $steps;
    }

    # Sampling steps
    if (my $sampling = $params->{sampling_steps}) {
        push @cmd, "--sampling_steps", $sampling;
    }

    # Output format
    if (my $format = $params->{output_format}) {
        push @cmd, "--output_format", $format;
    }

    # Use potentials
    if ($params->{use_potentials}) {
        push @cmd, "--use_potentials";
    }

    # Write PAE matrix
    if ($params->{write_full_pae}) {
        push @cmd, "--write_full_pae";
    }

    # Accelerator (default GPU)
    my $accelerator = $params->{accelerator} // "gpu";
    push @cmd, "--accelerator", $accelerator;

    # Execute boltz
    print "Executing: " . join(" ", @cmd) . "\n";

    my $rc = system(@cmd);
    if ($rc != 0) {
        die "Boltz prediction failed with exit code: $rc\n";
    }

    print "Boltz prediction completed successfully\n";

    # Upload results to workspace
    my $output_path = $params->{output_path};
    die "Output path is required\n" unless $output_path;

    print "Uploading results to workspace: $output_path\n";
    upload_results($app, $output_dir, $output_path);

    print "Boltz job completed\n";
    return 0;
}

=head2 detect_input_format

Detect whether input is YAML or FASTA format.

=cut

sub detect_input_format {
    my ($file, $hint) = @_;

    # If format is explicitly specified and not "auto"
    if ($hint && $hint ne "auto") {
        return $hint;
    }

    # Detect by extension
    if ($file =~ /\.ya?ml$/i) {
        return "yaml";
    } elsif ($file =~ /\.fa(sta)?$/i) {
        return "fasta";
    }

    # Try to detect by content
    my $content = read_file($file, { binmode => ':raw' });
    if ($content =~ /^(version:|sequences:)/m) {
        return "yaml";
    } elsif ($content =~ /^>/m) {
        return "fasta";
    }

    # Default to yaml
    return "yaml";
}

=head2 download_workspace_file

Download a file from the BV-BRC workspace.

=cut

sub download_workspace_file {
    my ($app, $ws_path, $local_dir) = @_;

    my $basename = basename($ws_path);
    my $local_path = "$local_dir/$basename";

    # Use workspace API to download
    if ($app && $app->can('workspace')) {
        try {
            $app->workspace->download_file($ws_path, $local_path);
        } catch {
            die "Failed to download $ws_path: $_\n";
        };
    } else {
        # Fallback for testing without workspace
        if (-f $ws_path) {
            copy($ws_path, $local_path) or die "Copy failed: $!\n";
        } else {
            die "File not found: $ws_path\n";
        }
    }

    return $local_path;
}

=head2 upload_results

Upload prediction results to the BV-BRC workspace.

=cut

sub upload_results {
    my ($app, $local_dir, $ws_path) = @_;

    # Find all output files
    my @files;
    find_files($local_dir, \@files);

    for my $file (@files) {
        my $rel_path = $file;
        $rel_path =~ s/^\Q$local_dir\E\/?//;

        my $ws_file = "$ws_path/$rel_path";
        print "Uploading: $file -> $ws_file\n";

        if ($app && $app->can('workspace')) {
            try {
                # Determine file type for workspace
                my $type = "txt";
                if ($file =~ /\.cif$/i) {
                    $type = "structure";
                } elsif ($file =~ /\.pdb$/i) {
                    $type = "structure";
                } elsif ($file =~ /\.json$/i) {
                    $type = "json";
                } elsif ($file =~ /\.npz$/i) {
                    $type = "binary";
                }

                # Upload with overwrite enabled (5th param = 1)
                $app->workspace->save_file_to_file($file, {}, $ws_file, $type, 1);
            } catch {
                warn "Failed to upload $file: $_\n";
            };
        }
    }
}

=head2 find_files

Recursively find all files in a directory.

=cut

sub find_files {
    my ($dir, $files) = @_;

    opendir(my $dh, $dir) or return;
    while (my $entry = readdir($dh)) {
        next if $entry =~ /^\./;
        my $path = "$dir/$entry";
        if (-d $path) {
            find_files($path, $files);
        } else {
            push @$files, $path;
        }
    }
    closedir($dh);
}

=head2 find_boltz_binary

Find the boltz binary. Checks in order:
1. boltz in PATH
2. P3_BOLTZ_PATH environment variable
3. Default path /opt/conda/bin

=cut

sub find_boltz_binary {
    my $binary = "boltz";

    # Check if boltz is in PATH by iterating PATH entries
    if (my $path_env = $ENV{PATH}) {
        my @path_dirs = split(/:/, $path_env);
        for my $dir (@path_dirs) {
            next unless $dir;  # Skip empty entries
            my $full_path = "$dir/$binary";
            if (-x $full_path && !-d $full_path) {
                return $full_path;
            }
        }
    }

    # Check P3_BOLTZ_PATH environment variable
    if (my $boltz_path = $ENV{P3_BOLTZ_PATH}) {
        my $bin_path = "$boltz_path/$binary";
        if (-x $bin_path) {
            return $bin_path;
        }
    }

    # Default to /opt/conda/bin
    $ENV{P3_BOLTZ_PATH} //= "/opt/conda/bin";
    return "$ENV{P3_BOLTZ_PATH}/$binary";
}

__END__

=head1 AUTHOR

BV-BRC Team

=head1 LICENSE

MIT License

=cut
