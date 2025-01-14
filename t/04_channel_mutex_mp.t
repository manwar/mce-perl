#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
   plan skip_all => "Not used on MSWin32" if ( $^O eq 'MSWin32' );

   use_ok 'MCE::Channel';
   use_ok 'MCE::Channel::Mutex';
}

my $chnl = MCE::Channel->new( impl => 'Mutex', mp => 1 );
is $chnl->impl, 'Mutex', 'implementation name';

# send recv
{
   $chnl->send('a string');
   is $chnl->recv, 'a string', 'send recv scalar';

   $chnl->send(qw/ a list of arguments /);
   is scalar( my @args = $chnl->recv ), 4, 'send recv list';

   $chnl->send({ complex => 'structure' });
   is ref( $chnl->recv ), 'HASH', 'send recv complex';
}

# send recv_nb
{
   $chnl->send('a string');
   is $chnl->recv_nb, 'a string', 'send recv_nb scalar';

   $chnl->send(qw/ a list of arguments /);
   is scalar( my @args = $chnl->recv_nb ), 4, 'send recv_nb list';

   $chnl->send({ complex => 'structure' });
   is ref( $chnl->recv_nb ), 'HASH', 'send recv_nb complex';
}

# send2 recv2
{
   $chnl->send2('a string');
   is $chnl->recv2, 'a string', 'send2 recv2 scalar';

   $chnl->send2(qw/ a list of arguments /);
   is scalar( my @args = $chnl->recv2 ), 4, 'send2 recv2 list';

   $chnl->send2({ complex => 'structure' });
   is ref( $chnl->recv2 ), 'HASH', 'send2 recv2 complex';
}

# send2 recv2_nb
{
   $chnl->send2('a string');
   is $chnl->recv2_nb, 'a string', 'send2 recv2_nb scalar';

   $chnl->send2(qw/ a list of arguments /);
   is scalar( my @args = $chnl->recv2_nb ), 4, 'send2 recv2_nb list';

   $chnl->send2({ complex => 'structure' });
   is ref( $chnl->recv2_nb ), 'HASH', 'send2 recv2_nb complex';
}

# enqueue dequeue
{
   $chnl->enqueue('a string');
   is $chnl->dequeue, 'a string', 'enqueue dequeue scalar';

   $chnl->enqueue(qw/ a list of items /);
   is scalar( my $item1 = $chnl->dequeue ), 'a',     'enqueue dequeue item1';
   is scalar( my $item2 = $chnl->dequeue ), 'list',  'enqueue dequeue item2';
   is scalar( my $item3 = $chnl->dequeue ), 'of',    'enqueue dequeue item3';
   is scalar( my $item4 = $chnl->dequeue ), 'items', 'enqueue dequeue item4';

   $chnl->enqueue({ complex => 'structure' });
   is ref( $chnl->dequeue ), 'HASH', 'enqueue dequeue complex';

   $chnl->enqueue(qw/ a b c /);
   is join( '', $chnl->dequeue(3) ), 'abc', 'enqueue dequeue count';
}

# enqueue dequeue_nb
{
   $chnl->enqueue('a string');
   is $chnl->dequeue_nb, 'a string', 'enqueue dequeue_nb scalar';

   $chnl->enqueue(qw/ a list of items /);
   is scalar( my $item1 = $chnl->dequeue_nb ), 'a',     'enqueue dequeue_nb item1';
   is scalar( my $item2 = $chnl->dequeue_nb ), 'list',  'enqueue dequeue_nb item2';
   is scalar( my $item3 = $chnl->dequeue_nb ), 'of',    'enqueue dequeue_nb item3';
   is scalar( my $item4 = $chnl->dequeue_nb ), 'items', 'enqueue dequeue_nb item4';

   $chnl->enqueue({ complex => 'structure' });
   is ref( $chnl->dequeue_nb ), 'HASH', 'enqueue dequeue_nb complex';

   $chnl->enqueue(qw/ a b c /);
   is join( '', $chnl->dequeue_nb(3) ), 'abc', 'enqueue dequeue_nb count';
}

# end
{
   $chnl->enqueue("item $_") for 1 .. 2;
   $chnl->end;

   for my $method (qw/ send enqueue /) {
      local $SIG{__WARN__} = sub {
         is $_[0],
         "WARNING: ($method) called on a channel that has been 'end'ed\n",
         "channel ended, $method";
      };
      $chnl->$method("item");
   }

   is $chnl->dequeue_nb, 'item 1', 'channel ended, dequeue_nb item 1';
   is $chnl->dequeue_nb, 'item 2', 'channel ended, dequeue_nb item 2';
}

done_testing;

