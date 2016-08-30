#!/usr/bin/perl -T
#
# Copyright (C) 2012-2014 United States Government as represented by the
# Administrator of the National Aeronautics and Space Administration
# (NASA).  All Rights Reserved.
#
# This software is distributed under the NASA Open Source Agreement
# (NOSA), version 1.3.  The NOSA has been approved by the Open Source
# Initiative.  See http://www.opensource.org/licenses/nasa1.3.php
# for the complete NOSA document.
#
# THE SUBJECT SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY WARRANTY OF ANY
# KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT
# LIMITED TO, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL CONFORM TO
# SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
# A PARTICULAR PURPOSE, OR FREEDOM FROM INFRINGEMENT, ANY WARRANTY THAT
# THE SUBJECT SOFTWARE WILL BE ERROR FREE, OR ANY WARRANTY THAT
# DOCUMENTATION, IF PROVIDED, WILL CONFORM TO THE SUBJECT SOFTWARE. THIS
# AGREEMENT DOES NOT, IN ANY MANNER, CONSTITUTE AN ENDORSEMENT BY
# GOVERNMENT AGENCY OR ANY PRIOR RECIPIENT OF ANY RESULTS, RESULTING
# DESIGNS, HARDWARE, SOFTWARE PRODUCTS OR ANY OTHER APPLICATIONS RESULTING
# FROM USE OF THE SUBJECT SOFTWARE.  FURTHER, GOVERNMENT AGENCY DISCLAIMS
# ALL WARRANTIES AND LIABILITIES REGARDING THIRD-PARTY SOFTWARE, IF
# PRESENT IN THE ORIGINAL SOFTWARE, AND DISTRIBUTES IT "AS IS".
#
# RECIPIENT AGREES TO WAIVE ANY AND ALL CLAIMS AGAINST THE UNITED STATES
# GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR
# RECIPIENT.  IF RECIPIENT'S USE OF THE SUBJECT SOFTWARE RESULTS IN ANY
# LIABILITIES, DEMANDS, DAMAGES, EXPENSES OR LOSSES ARISING FROM SUCH USE,
# INCLUDING ANY DAMAGES FROM PRODUCTS BASED ON, OR RESULTING FROM,
# RECIPIENT'S USE OF THE SUBJECT SOFTWARE, RECIPIENT SHALL INDEMNIFY AND
# HOLD HARMLESS THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND
# SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT, TO THE EXTENT PERMITTED
# BY LAW.  RECIPIENT'S SOLE REMEDY FOR ANY SUCH MATTER SHALL BE THE
# IMMEDIATE, UNILATERAL TERMINATION OF THIS AGREEMENT.
#

# This program is a template that can be used to periodically collect file
# system information for Shift, which is used to determine file system
# equivalence for client spawns and transfer load balancing.

use strict;
use File::Temp;
use POSIX qw(setuid);

our $VERSION = 0.06;

# untaint PATH
$ENV{PATH} = "/bin:/usr/bin:/usr/local/bin";

############################
#### begin config items ####
############################

# user to use for ssh
#   (it is assumed this script will be invoked from root's crontab)
my $user = "someuser";

# set of hosts to collect mount information from
#   (it is assumed hostbased authentication can be used to reach all hosts)
#   (it is assumed shift-aux is in the default path on all hosts)
my @hosts = qw(
    host1 host2 ... hostN
);

# host where manager invoked
#   (it is assumed hostbased authentication can be used to reach this host)
#   (it is assumed shift-mgr is in the default path on this host)
my $mgr = "somehost";

##########################
#### end config items ####
##########################

# drop privileges and become defined user
my $uid = getpwnam($user);
setuid($uid) if (defined $uid);
die "Unable to setuid to $user\n"
    if (!defined $uid || $< != $uid || $> != $uid);

# create temporary file (automatically unlinked on exit)
my $tmp = File::Temp->new;
my $file = $tmp->filename;
close $tmp;

# gather info from all hosts
foreach my $host (@hosts) {
    open(TMP, ">>$file");
    # use shift-aux to collect mount information and append to file
    open(FILE, "ssh -aqx -oHostBasedAuthentication=yes -oBatchMode=yes -l $user $host shift-aux mount |");
    while (<FILE>) {
        # print once for fully qualified host
        print TMP $_;
        # ignore shell line for plain host
        next if (!/^args=/ || /^args=shell/);
        # replace fully qualified host with plain host
        s/(host=$host)\.\S+/$1/;
        # duplicate line for plain host
        print TMP $_;
    }
    close FILE;
    close TMP;
}

# call shift-mgr to add collected info to global database
system("ssh -aqx -oHostBasedAuthentication=yes -oBatchMode=yes -l $user $mgr shift-mgr --mounts < $file");

