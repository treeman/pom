#!/usr/bin/env perl6

use v6;
#use DBIish;
#use JSON::Tiny;
#use DateTime::Format;
#use Term::ANSIColor;

use lib '.'; # Add current search directory for lib search

# TODO use database instead of a file for storage...
# TODO move into me?
my $status_file = "$*TMPDIR/pom.status".IO;

# Would be nice to have rust enum semantics. Does it exists here?
enum Status <WORK PAUSE WAIT_WORK WAIT_PAUSE STOPPED>;

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
#F73A47 red
#F78B3A orange
#F7EA3A yellow
#F73AA6 pink/purple
#EA3AF7 purple
sub print_status($work_time, $pause_time, Bool $conky) {
    my ($status, $elapsed) = get_status();
    my $remaining = get_remaining($status, $elapsed, $work_time, $pause_time);

    if $status eq WORK {
        #if $conky { print "^p(2)^i(/home/tree/code/pom/pom.xbm)^p(2) ^fg(\\#F73A47)" }
        if $conky { print "^bg(\\#F78B3A)^fg(\\#313131) " }
        #if $conky { print "^bg()^fg(\\#F78B3A) " }
        print "Work: ", format_elapsed($remaining);
        if $conky { print " ^bg()" }
    }
    elsif $status eq PAUSE {
        #if $conky { print "^bg()^fg(\\#F7EA3A) " }
        if $conky { print "^bg(\\#3AF773)^fg(\\#313131) " }
        print "Pause ", format_elapsed($remaining);
        if $conky { print " ^bg()" }
    }
    elsif $status eq WAIT_WORK {
        if $conky { print "^bg(\\#F73A47)^fg(\\#313131) " }
        print "Waiting for Work";
        if $conky { print " ^bg()" }
    }
    elsif $status eq WAIT_PAUSE {
        if $conky { print "^bg(\\#F73A47)^fg(\\#313131) " }
        print "Waiting for Pause";
        if $conky { print " ^bg()" }
    }
    else {
        print "Stopped";
    }
    print "\n" unless $conky;
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

# continue was taken... :)
sub start_next {
    my ($status, $elapsed) = get_status();

    # Should be a better way of doing these?
    if ($status eq WORK) || ($status eq WAIT_PAUSE) {
        start_pause();
    }
    elsif ($status eq PAUSE) || ($status eq WAIT_WORK) || ($status eq STOPPED) {
        start_work();
    }
}

sub wait_for_work {
    my $fh = open $status_file, :w;
    $fh.print("WAIT_WORK ", time);
    $fh.close;

    run 'play', '-v', '0.4', '~/code/pom/pause_done.wav';
}

sub wait_for_pause {
    my $fh = open $status_file, :w;
    $fh.print("WAIT_PAUSE ", time);
    $fh.close;

    run 'play', '-v', '0.4', '~/code/pom/work_done.wav';
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

    if ($status eq WORK) && ($elapsed > $work_time) {
        wait_for_pause();
    }
    elsif ($status eq PAUSE) && ($elapsed > $pause_time) {
        wait_for_work();
    }
}

sub MAIN(Bool :$stop, Bool :$start_work, Bool :$start_pause, Bool :$continue,
         Int :$work_time = 60 * 40, Int :$pause_time = 60 * 15,
         Bool :$conky)
{
    if $continue { start_next() }
    elsif $start_work { start_work() }
    elsif $start_pause { start_pause() }
    elsif $stop { stop() }
    else { update($work_time, $pause_time) }

    print_status($work_time, $pause_time, $conky);
}

