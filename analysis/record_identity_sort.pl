#!/usr/bin/perl -w -I /home/ucat/modules -I/usr/sbin

#N.B. in some nevironment,s if exporting Marc21 to run this script manually, enter export LANG='en_GB' at the command
#line BEFORE executing the script.



# RUN with perl record_identitiy_sort.pl -m -f Temp035Multiples.txt

############## 
#Original record sorting spec  
##############
#1. BNB data
#
#Any record with a BNB number in an 015 field, where a "BNB number" is either a 9-character string starting "GB" or (to be slightly more inclusive) content whose first "word" is such a string
#
#Notes: it is almost unknown for BNB records to be provided manually, so any record containing such an 015 is almost certain to have originated with, and be covered by our agreements with the BL, rather than with other third parties
#
#
#Of the remainder:
#
#2. OCLC data
#
#[See also e-mail of 15/6/11 - Multiple 035s and other identifying characteristics] Any other record with an OCLC number in one of the 035 fields. That is:
#    035 begins "(OCoLC)"
#    and if there's an 038 then it must be "OCoLC"
#
#Notes: Requires a different licence from most of our data
#
#
#Of the remainder:
#
#3. The rest! (minus the problems...)
#
#All remaining records **except** those that we don't have permission to share in this way - here's what I believe to be a complete list:
#    Agency for the Legal Deposit Libraries - (StEdALDL)
#    ESTC from UC Riverside - (CU-RivES)
#    Touzot - (FrPJT) or string starting "JTL" 

# CURL/rluk clause in 035? - DONE 
# 994 field test - probably best placed efter the 038 one. Very simple: if there's a 994 then it's an OCLC record. -  DONE
# in addition to the "BNB" prefix, treat 015s starting "mu" (or "MU" in the normalized form) as British Library numbers and covered by BL permissions - DONE
# Improve OCLC regex - specific by looking for "ocm"+up to 8 digits, or "ocn"+9 digits, Done
# TO amend - SORT those with no ID to a cambridge file - YES?

#modules
use DBI;
#use MARC;
use MARC::Batch;
use MARC::Record;
use MARC::File::USMARC;
use MARC::Field;
use MARC::Lint::CodeData;
use Getopt::Std;
use Data::Dumper;
#ensures good behaviour
use strict;

my $query = "sql_sort";
our $path="/home/ucat/comet/scripts/$query/";
print "path: $path \n";
#date/time
my ($min, $hour, $day, $month, $year)=(localtime)[1,2,3,4,5];
$month=$month+1;
$year=$year+1900;
if ($day<10) {
    $day="0".$day;}
if ($month<10) {
    $month="0".$month;}
if ($min<10) {
    $min="0".$min;}
if ($hour<10) {
    $hour="0".$hour;}
my $date=$day.'/'.$month.'/'.$year;
#date for files (no slashes)
my $filedate=$year.$month.$day."_".$hour.$min;

my ($mode,$inFile, $idFh,$BNB,$OCLC, $PD, $OTH, $SKIP, $RLUK, $rlukfn,  $pdfn, $skipfn,$bnbfn,$oclcfn,$other,$record,$subFieldValue,$hit,$prohibit) = '';
our ($opt_f,$opt_m) = '';

#if ($ARGV[0]) {
    
getopts('m:f:');
 
 if ($opt_m) {
           $mode = 'marc';
         } else {
            $mode = 'id';
         }
 
 
if ($opt_f) {
           $inFile=$opt_f;      
         } else {
            $inFile = $ARGV[0];   
         }
 
print "Reading $inFile \n";


if ($opt_m) {
    print "Writing full marc records as output \n";
    $bnbfn = 'bnb'. $filedate. '.mrc';
    $oclcfn =  'oclc' . $filedate. '.mrc';
    $other = 'other'  . $filedate. '.mrc';
    $rlukfn ='rluk'  . $filedate. '.mrc';
    $pdfn ='pd'  . $filedate. '.mrc';
} else {
    $bnbfn = 'bnb'. $filedate. '.txt';
    $oclcfn =  'oclc' . $filedate. '.txt';
    $other = 'other'  . $filedate. '.txt';
    $rlukfn ='rluk'  . $filedate. '.txt';
    $pdfn ='pd'  . $filedate. '.txt';
}

$skipfn = 'skipped' . $filedate. '.txt';

#results files
open ($BNB, ">:utf8", $bnbfn) or die "Could not open bnb file: $!";
open ($OCLC, ">:utf8", $oclcfn) or die "Could not open bnb file: $!";
open ($OTH, ">:utf8", $other) or die "Could not open bnb file: $!";
open ($SKIP, ">:utf8", $skipfn) or die "Could not open bnb file: $!";
open ($RLUK, ">:utf8", $rlukfn) or die "Could not open bnb file: $!";
open ($PD, ">:utf8", $pdfn) or die "Could not open bnb file: $!";
open (LOG, "> log_$filedate.txt") or die "could not open log: $!";


# Alternaitve load mechanism - uncomment the following and alter SQL and DBI setting as required to take either a list of ID's from a library management system
# oR scan a whole system - current SQL is for Voyager LMS. 

# Also uncomment sub at the bottom ...

##DB details and dbh
#my $database = "";
#my $driver = "";
#my $dbase="";
##connects to database
#my $dbh=DBI->connect("$driver:$database", "","") or die "Could not connect to database: $!";
#
## Begin database inital query stuff -incase we want to use SQL rather than a file of BIB_ID's
#my $bibs_sql=qq(SELECT DISTINCT(BIB_MASTER.BIB_ID)
#		FROM BIB_MASTER INNER JOIN LIBRARY ON BIB_MASTER.LIBRARY_ID=LIBRARY.LIBRARY_ID
#		WHERE BIB_MASTER.SUPPRESS_IN_OPAC='N'
#		AND LIBRARY.LIBRARY_NAME<>'Electronic Books');
#
#my $startBib = 3785764;
#
#if ($startBib) {$bibs_sql.=" AND BIB_MASTER.BIB_ID >= $startBib";}
#
##if ($endBib) {$bibs_sql.=" AND BIB_MASTER.BIB_ID <= $endBib";}
#
#$bibs_sql.=" ORDER BY BIB_MASTER.BIB_ID";
#
#my $sth_bibs=$dbh->prepare($bibs_sql);
#
#$sth_bibs->execute();
#print "bib_ids extracted, commencing processing ... \n";
## End database query stuff ...
#
## Instead of an SQL statement for BIB_ID's, we can just access an existing file , comment out the next two lines to swap ...
##open (idFh, "<", $marcIDFile) or die "Cannot open: $!";
##while (my $bib_id = <idFh>) {
#
#while (my $bib_id=$sth_bibs->fetchrow_array){
#	$record = get_bib_marc_record($dbh, $bib_id, $path);'


        # Open MARC file
        my $bulk=MARC::File::USMARC->in($inFile);
         # Loop through MARC recordset
        my $count=0;

         eval{
         while (my $record=$bulk->next()){
	   my $bib_id='';
	   my $field_001=$record->field('001');
                  if ($field_001){
                           $field_001=$field_001->data();
			   $bib_id = $field_001;
                  }  
	    
   # bib_id =~ s/\r//g;
    
    $hit='';
   
   # Uncomment this to directl pull records from an SQL database rather than parse a bulk file ...
#     eval{
#	$record = get_bib_marc_record($dbh, $bib_id, $path);
#     };
     
     # Log failure and skip ...
#    if ($@) {
#          print LOG "FAILED TO OPEN  $bib_id \n";
#	next;
#	
#    }
#    elsif(!$record){
#	
#	next;
#	
#    }else{


	print $bib_id ."\n";
	print LOG $bib_id . " read ... \n";
	#print LOG Dumper($record);
	$hit=0;
	$prohibit ='';
	
# Clause for 015 - BNB ... Agreements with RLUK superseed all other entries...
################################# 015 clause ...
	   

	   if ($record->field('015')) {
	   #  print  "FOUND 015 !!!!!!!!!!! ... \n";
		@015 = $record->field('015');
		   # If there are 015 fields present starting with GB, its a BNB ...
		 foreach my $each015(@015) {
		     $subFieldValue = $each015->subfield('a');
		     $subFieldValue =~ s/[^a-zA-Z0-9-\s]//g;  
			 if ($subFieldValue  =~ /^GB[\w]{7}|^mu|MU[\w]/) {
			     # print  "BNB HIT !!!!!!!!!!! ... \n";
				    # its a BNB ... add to BNB output
				      # its a BNB ... add to BNB output
			     $hit=1;
			     last;
			 } else {
			  #   print  "015 BUT NOT BNB !!!!!!!!!!! ... \n";
			 }
		      
		 } # End 015 loop

		if ($hit==1) {
		      if ( $mode eq 'marc') {
				   print $BNB $record->as_usmarc;
			       } else {
				    print $BNB $bib_id . "\n";
			       }
			       
		    print "$bib_id - BNB 015 match - $subFieldValue\n";
		    print LOG "$bib_id - BNB 015 match - $subFieldValue\n";
		 # Move on in the loop, no need to check o35 and 038 ...
		next;
		} 
########################### 038 clause ...

	    } if ($record->field('038'))   {
	   #  print  "FOUND O38 !!!!!!!!!!! ... \n";
		    @038 = $record->field('038');
			      foreach my $each038(@038) {
				$subFieldValue = $each038->subfield('a');
				$subFieldValue =~ s/[^a-zA-Z0-9-\s]//g;  
				if ($subFieldValue =~ /^OCoLC[\w]*/) {
				  # If there are 038 fields present, then its OCLC ...
				  $hit=1;
				  last;
				  } 
				  
				elsif($subFieldValue =~ /^UkLCURL[\w]*/) {
				  $hit=2;
				  last;
				 }
				 
		  } #End 038 loop
		  # got a hit,
		      if ($hit==1) {
			   if ( $mode eq 'marc') {
				  print $OCLC $record->as_usmarc;
				  } else {
				  print $OCLC $bib_id . "\n";
				  }
		    print "$bib_id - OCLC 038 match - $subFieldValue\n";
		    print LOG "$bib_id - OCLC 038 match - $subFieldValue\n";
		     # Move on in the loop, no need to check 015 ...
		      next;
		      } elsif($hit==2) {
			  if ( $mode eq 'marc') {
				  print $RLUK $record->as_usmarc;
				  } else {
				  print $RLUK $bib_id . "\n";
				  }
		    print "$bib_id - RLUK 038 match - \n";
		    print LOG "$bib_id - RLUK 038 match - $subFieldValue\n";
		     # Move on in the loop, no need to check 015 ...
		     next;
		     }
		      
		      
		      
 ################################## Simple 944 clause ...
	      } if ($record->field('994'))   {
	           # print  "FOUND 994 !... \n";
		   if ( $mode eq 'marc') {
				  print $OCLC $record->as_usmarc;
				  } else {
				  print $OCLC $bib_id . "\n";
				  }
		    print "$bib_id - OCLC 994 match - $subFieldValue\n";
		    print LOG "$bib_id - OCLC 994 match - $subFieldValue\n";
		     # Move on in the loop, no need to check 015 ...
		      next;
		   
		
############################## Last of all we sith the 035, the most problematic of them all ...
	    	    
	    } if ($record->field('035'))   {
		  
		  #print LOG "FOUND O35 !!!!!!!!!!! ... \n";
		  
		     @035 = $record->field('035');
			foreach my $each035(@035) {
			# Run through all subfields to find an a or a z. Then strip of punctuation. 
			$subFieldValue = $each035->subfield('a');
			
			
			
			if ($subFieldValue) {
			        print "$subFieldValue .\n";
				$subFieldValue =~ s/[^a-zA-Z0-9-\s]//g;
				#print LOG $bib_id . " - 035" .$subFieldValue . " \n";
		    
				
			# ADD EBOOKS, SerSol etc ....
			 #SITUATION #2 exit loop, as we cannot share records from vendors with these codes ...
			    if ($subFieldValue =~ /^StEdALDL|^CU-RivES|^JTL|^FrPJT|^WaSeSS/ ) {
					print "$bib_id  - CONTRACT prohibited: - $subFieldValue\n";
					print LOG "$bib_id  - CONTRACT prohibited: - $subFieldValue\n";
					print $SKIP "$bib_id  \n";
					$prohibit='yes';
					last;
				   }
			    
			    # #SITUATION #3 ITs OCLC under older descriptions ...
			    elsif ($subFieldValue =~ /^OCoLC[\w]*|^ocn[\d]*|^ocm[\d]*/) {
					# ITs an OCLC add to prefered output
					 if ($mode eq 'marc') {
					    print $OCLC $record->as_usmarc;
					 }else {
					    print $OCLC $bib_id . "\n";
					 }
					  print " $bib_id - OCLC 035 match in $subFieldValue \n";
				          print LOG " $bib_id - OCLC 035 match in $bib_id - $subFieldValue\n";
					$prohibit='yes';
					last;
			               } elsif ($subFieldValue =~ /^UkLCURL[\w]*/) {
					# ITs an OCLC add to prefered output
					 if ($mode eq 'marc') {
					    print $RLUK $record->as_usmarc;
					 }else {
					    print $RLUK $bib_id . "\n";
					 }					 
					      print "$bib_id - RLUK 035 match - \n";
					     print LOG "$bib_id - RLUK 035 match - $subFieldValue\n";
					$prohibit='yes';
					last;
					}
			       } # end subfuield check
			
			} # end 035 loop
			
			   #SITUATION #3 Its got an 035, not prohibited or not an OCLC so we can share it ...
	                if ($prohibit ne 'yes') {
				if ($mode eq 'marc') {
				print $OTH $record->as_usmarc;
				} else {
				print $OTH $bib_id . "\n";
				 }
			print "$bib_id Other 035 matches - no contractual reason not to share:   \n";  
			print LOG "$bib_id  Other 035 matches - no contractual reason not to share: \n";
			next;
	               }
	    } # end 035 loop
	    
	     # No 015,038 or 035 so skip as we have already PD'd those ..
	    if  ((!$record->field('015')) && (!$record->field('038')) && (!$record->field('035')) && (!$record->field('994'))) {
	     print LOG "$bib_id - No 015, 035 or 038 so PD \n";
	     print "$bib_id PD no identifer \n";
	    
	    if ($mode eq 'marc') {
				print $PD $record->as_usmarc;
				} else {
				print $PD $bib_id . "\n";
				 }
	    }
	    
	    
	    

$record ='';
} # End record loop

 }


#END MAIN
##################
#sub get_bib_marc_record{
#    
#    my ($dbh, $bib_id, $path)=@_;
#
#    my $marc;
#
#    
#    my $marc_sql=qq(SELECT RECORD_SEGMENT
#                    FROM BIB_DATA
#                    WHERE BIB_ID=?
#                    ORDER BY SEQNUM);
#                    
#    my $sth_marc=$dbh->prepare($marc_sql);
#
#    $sth_marc->execute($bib_id) or die "Could not find record in db: $!";;
#
#    while (my $marc_segment=$sth_marc->fetchrow_array()){
#        $marc.=$marc_segment;
#    }
#        
#    my $marc_filename=$path."bib_marc.mrc";
#        
#    open (MARC_FILE, "> $marc_filename") or die "Could not open marc file: $!";
#        
#    print MARC_FILE "$marc";
#        
#    close (MARC_FILE);
#
##generates MARC object for bib record
#    my $x=MARC::Record->new("$marc_filename") or die "Could not proccess marc file: $!";;
#        
#    my $marc_file=MARC::File::USMARC->in($marc_filename);
#        
#    my $record=$marc_file->next();
#    
#    return $record;
#    
#}