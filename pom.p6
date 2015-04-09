#!/usr/local/bin/perl6

use v6;
#use DBIish;
#use JSON::Tiny;
#use DateTime::Format;
#use Term::ANSIColor;

use lib '.'; # Add current search directory for lib search

my $status_file = "$*TMPDIR/pom.status".IO;

# Would be nice to have rust enum semantics. Does it exists here?
enum Status <WORK PAUSE STOPPED>;

sub get_status {
    if $status_file ~~ :f {
        my ($status, $last) = split(/\s+/, slurp $status_file);
        return $status, time - $last;
    }
    else {
        return STOPPED;
    }
}

sub get_remaining($status, $elapsed, $work_time, $pause_time) {
    if $status eq WORK {
        return $work_time - $elapsed;
    }
    elsif $status eq PAUSE {
        return $pause_time - $elapsed;
    }
    else {
        return 0;
    }
}

sub print_status($work_time, $pause_time, Bool $conky) {
    my ($status, $elapsed) = get_status();
    my $remaining = get_remaining($status, $elapsed, $work_time, $pause_time);
    if $status eq WORK {
        #if $conky { print "^p(2)^i(/home/tree/code/pom/pom.xbm)^p(2) ^fg(\\#F73A47)" }
        if $conky { print "^bg(\\#F73A47)^fg(\\#B1B1B1)" }
        print "Work: ", format_elapsed($remaining);
        if $conky { print "^bg()" }
    }
    elsif $status eq PAUSE {
        if $conky { print "^bg(\\#F7EA3A)^fg(\\#B1B1B1)" }
        print " Pause ", format_elapsed($remaining), " ";
        if $conky { print "^bg()" }
    }
    else {
        say "Stopped";
    }
}

# Should have a standardized formatting function somewhere, but can't find it.
# Whatever.
sub format_elapsed($dt) {
    my $sec = $dt;
    my $min = 0;
    if $sec > 60 {
        $min = Int($sec / 60);
        $sec = $sec % 60;
    }

    #return $min ~ "m " ~ $sec ~ "s";
    return $min ~ "m";
}

sub start_work {
    my $fh = open $status_file, :w;
    $fh.print("WORK ", time);
    $fh.close;
}

sub start_pause {
    my $fh = open $status_file, :w;
    $fh.print("PAUSE ", time);
    $fh.close;
}

sub restart {
    start_work();
}

sub stop {
    unlink $status_file;
}

# FIXME if script is not run regularly, we might skip work/pause times!
sub update(Int $work_time, Int $pause_time) {
    my ($status, $elapsed) = get_status();

    #say "Status: $status";
    #say "Elapsed: $elapsed";
    #say "Work: $work_time";
    #say "Pause $pause_time";

    if ($status eq WORK) && ($elapsed > $work_time) {
        #say "Time to work again!";
        start_pause();
    }
    elsif ($status eq PAUSE) && ($elapsed > $pause_time) {
        #say "Time for a nice pause!";
        start_work();
    }
}

sub MAIN(Bool :$stop, Bool :$restart, Int :$work_time = 60 * 40,
         Int :$pause_time = 60 * 15, Bool :$conky)
{
    if $restart { restart() }
    elsif $stop { stop() }
    else { update($work_time, $pause_time) }

    print_status($work_time, $pause_time, $conky);
}

