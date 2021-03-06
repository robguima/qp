Storing DNS host names in [qp tries](http://dotat.at/prog/qp)
====================================

A few thoughts on tuning qp tries for storing DNS names, inspired by
Knot DNS. They found that HAT tries were faster than qp tries, mainly
due to requiring fewer memory indirections - HAT tries indirect once
per byte for dense key sets, whereas qp tries indirect twice. Knot is
using the 4 bit version of qp tries; the 5 bit version is unlikely to
be much better in this application.


String theory
--------------

One of the criteria for the design of qp tries was to allow arbitrary
C strings as keys, without undue length restrictions. So as much space
as possible is reserved in the branch word for the key index.

For DNS names, the maximum length is very small, so there's plenty of
space for other purposes.

The usual alphabet for DNS names is case-insensitive letters, digits,
hyphens, sometimes underscore, plus an end-of-label marker which does
not have an octet value. However it is possible to use any octet value
(including zero!) though it is rare.


Idea
----

There are two kinds of branch nodes, a bit like the upper nybble and
lower nybble of qp-tries, except the split is more cunning.

Some of the bits in the upper node bitmap are allocated to whole byte
values:

* 26 case-insensitive letters

* 10 digits

* hyphen and underscore

* end-of-label

* 8 for upper 3 bits of non-hostname bytes

(total 47 bits)

That leaves space for

* 8 bit index

* 2 bit node type

* 7 spare

If the byte at the index is in the usual hostname alphabet, it is
handled by this upper node with one indirection.

If the byte is a non-hostname value, it is handled by a slow path. The
upper 3 bits of the byte are handled by the upper node, and the lower
5 bits by the lower node.

* 32 for lower 5 bits of non-hostname bytes

* 8 bit index

* 2 bit node type

* 22 spare


Turning names into keys
-----------------------

DNS names need some preparation for use as lexical keys. The labels
need to be in reverse order, and the length octets need to be
converted to some kind of non-byte value.

Instead of doing this with string manipulation, which might require
doubling the memory used to store names, it might make more sense to
use a descriptor of the string to make embedded octet lengths more
easy to use. The descriptor is just a list of the indexes of the
length bytes in reverse order, terminated with an extra zero. For
example, (using \digit to represent the length bytes)

        \4grey\3csi\3cam\2ac\2uk\0

needs a descriptor like

        19 16 13 9 5 0 0

The indexing code scans through the descriptor as you index further
into the name. There's an init step which can be run once before a qp
lookup:

        d = 0;
        limit = desc[d++];
        base = desc[d++];
        offset = -1;

Then each index looks like this, as long as i only increases.

        while(base + i - offset > limit) {
                if (limit == 0)
                        return(-1);
                offset += limit - base;
                limit = base;
                base = desc[d++];
        }
        if (base + i - offset == limit)
                return(-1);
        else
                return(key[base + i - offset]);

Caveat
------

The tricky bit of this scheme is iterating in order. For example, if
the upper 3 bits of an octet are 001 (hex values 0x20 - 0x3F) the
order of iteration has to switch back and forth between parent and
child node depending on whether the octet is a hyphen or digit or not.

The non-byte value has to sort before other values.

---------------------------------------------------------------------------

Written by Tony Finch <dot@dotat.at> <http://dotat.at/>;
You may do anything with this. It has no warranty.
<http://creativecommons.org/publicdomain/zero/1.0/>
