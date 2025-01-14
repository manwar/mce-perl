#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
   use_ok 'MCE::Flow';
   use_ok 'MCE::Queue';
}

##  preparation

my $in_file = MCE->tmp_dir . '/input.txt';
my $fh_data = \*DATA;

open my $fh, '>', $in_file;
binmode $fh;
print {$fh} "1\n2\n3\n4\n5\n6\n7\n8\n9\n";
close $fh;

##  output iterator to ensure output order

sub output_iterator {

   my ($gather_ref) = @_;
   my %tmp; my $order_id = 1;

   @{ $gather_ref } = ();     ## reset array

   return sub {
      my ($data_ref, $chunk_id) = @_;
      $tmp{ $chunk_id } = $data_ref;

      while (1) {
         last unless exists $tmp{$order_id};
         push @{ $gather_ref }, @{ $tmp{$order_id} };
         delete $tmp{$order_id++};
      }

      return;
   };
}

##  sub-tasks

my $q = MCE::Queue->new;

sub task_a {

   my ($mce, $chunk_ref, $chunk_id) = @_;
   my @ans; chomp @{ $chunk_ref };

   push @ans, map { $_ * 2 } @{ $chunk_ref };

   $q->enqueue( [ \@ans, $chunk_id ] );   # forward to task_b
}

sub task_b {

   while (defined (my $next_ref = $q->dequeue)) {
      my ($chunk_ref, $chunk_id) = @{ $next_ref };
      my @ans;

      push @ans, map { $_ * 3 } @{ $chunk_ref };

      MCE->gather(\@ans, $chunk_id);      # send to output_iterator
   }
}

##  Reminder; MCE::Flow processes sub-tasks from left-to-right

my $answers = '6 12 18 24 30 36 42 48 54';
my @a;

MCE::Flow::init {
   max_workers => [  2  ,  2  ],   # run with 2 workers for both sub-tasks
   task_name   => [ 'a' , 'b' ],

   task_end => sub {
      my ($mce, $task_id, $task_name) = @_;

      if ($task_name eq 'a') {
         # One might want to call $q->end(). Do not do that here.
         # This queue is used again, subsequently.

         $q->enqueue((undef) x 2);   # 2 workers
      }
   }
};

mce_flow { gather => output_iterator(\@a) }, \&task_a, \&task_b, ( 1..9 );
is( join(' ', @a), $answers, 'check results for array' );

mce_flow { gather => output_iterator(\@a) }, \&task_a, \&task_b, [ 1..9 ];
is( join(' ', @a), $answers, 'check results for array ref' );

mce_flow_f { gather => output_iterator(\@a) }, \&task_a, \&task_b, $in_file;
is( join(' ', @a), $answers, 'check results for path' );

mce_flow_f { gather => output_iterator(\@a) }, \&task_a, \&task_b, $fh_data;
is( join(' ', @a), $answers, 'check results for glob' );

mce_flow_s { gather => output_iterator(\@a) }, \&task_a, \&task_b, 1, 9;
is( join(' ', @a), $answers, 'check results for sequence' );

MCE::Flow::finish;

##  process hash, current API available since 1.828

MCE::Flow::init {
   max_workers => 1
};

my %hash = map { $_ => $_ } ( 1 .. 9 );

my %res = mce_flow sub {
   my ($mce, $chunk_ref, $chunk_id) = @_;
   my %ret;
   for my $key ( keys %{ $chunk_ref } ) {
      $ret{$key} = $chunk_ref->{$key} * 2;
   }
   MCE->gather(%ret);
}, \%hash;

@a = map { $res{$_} } ( 1 .. 9 );

is( join(' ', @a), "2 4 6 8 10 12 14 16 18", 'check results for hash ref' );

MCE::Flow::finish;

##  cleanup

unlink $in_file;

done_testing;

__DATA__
1
2
3
4
5
6
7
8
9
