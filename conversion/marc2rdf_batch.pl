#!/usr/bin/perl -w -I/usr/sbin 
# Marc21 to RDF batch conversion script
# Written by Huw Jones, Ed Chamberlain, Cambridge Univesity Library 2011
# Produced for the Comet project funded by JISC as part of the Infrastructure for Discovery
# All code licensed under the GPL - http://www.gnu.org/licenses/gpl.html

# fields for conversion can be entered into an appropriate acompanying csv file i.e. bibliographic.txt
# Namespaces for any fields used can be entered into the namespaces.txt csv file


use Switch;
use MARC::Record;
use MARC::File::USMARC;
use Data::Dumper;
use Scalar::Util;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Std;

use strict;
#we can safely turn off these warnings
no warnings "uninitialized";
#log file
open (LOG, "> log.txt") or die "could not open log: $!";

# parse namespaces config file ...
my %nameSpace = parseCSV('namespaces.txt');

our ($opt_f, $opt_u, $opt_d, $opt_o);

#defaults
my $uriBase='http://data.lib.cam.ac.uk/id/';
my $datasetId = 'cambrdgedb';

my $textNode = '<' . $uriBase . 'type/'.genGuidString("text") . '>';
my $monographNode = '<' . $uriBase . 'type/' . genGuidString("monographic") . '>';
my $manuscriptNode = '<' . $uriBase . 'type/' . genGuidString("manuscript") . '>';
my $continuingNode = '<' . $uriBase . 'type/' . genGuidString("continuing") . '>';
my $collectionNode = '<' . $uriBase . 'type/' . genGuidString("collection") . '>';
my $microfilmNode = '<' . $uriBase . 'type/' . genGuidString("microfilm reel") . '>';
my $microficheNode = '<' . $uriBase . 'type/' . genGuidString("microfiche") . '>';
my $microformNode = '<' . $uriBase . 'type/' . genGuidString("microform") . '>';
my $electronicNode = '<' . $uriBase . 'type/' . genGuidString("electronic") . '>';

#NON-BL
my $videoNode = '<' . $uriBase . 'type/' . genGuidString("video") . '>';
my $musicNode = '<' . $uriBase . 'type/' . genGuidString("music") . '>';
my $mapNode = '<' . $uriBase . 'type/' . genGuidString("map") . '>';
my $softwareNode = '<' . $uriBase . 'type/' . genGuidString("software") . '>';

#default nodes for date intervals

my $instantNode= '<' . $uriBase . 'chron/' . genGuidString("instant") . '>';
my $intervalNode= '<' . $uriBase . 'chron/' . genGuidString("interval") . '>';

         

#picks up infile from command line
# Main logic
if ($ARGV[0]) {
         
         # parse optional arguments or load up   
         getopts('o:u:d:f:');
         my ($marcFile,$outputFilename);
        
         # optional filename, else takes the argument ...
         if ($opt_f) {
           $marcFile=$opt_f;      
         } else {
            $marcFile = $ARGV[0];   
         }
         # Optional base URI 
         if ($opt_u) {
             $uriBase = $opt_u;
         }
         
         # Optional dataset ID
         if ($opt_d) {
            $datasetId = $opt_d;
         }
         
         # Optional filename for output
         if ($opt_o) {
            $outputFilename = $opt_o;
            print "Outputting to $outputFilename \n";
         } else {
             $outputFilename = "$marcFile" . "_triples.nt";
         }
         
         my $outputFile;
         
         open($outputFile, ">$outputFilename") or die $!;
         

         # Open MARC file
         my $inFile=MARC::File::USMARC->in($marcFile);
         # Loop through MARC recordset
         my $count=0;

         eval{

         while (my $record=$inFile->next()){ 
                  
                  my $field_001=$record->field('001');
                  if ($field_001){
                           $field_001=$field_001->data();
                  }
                  print LOG "$field_001 \n";
                  
                  #sets default for filename
                  my $fName='bibliographic_bl.txt';
                  #Check record format (008, pos 6) - Read format Book/Journal , Sheet music , other
                  my $formatCode = substr($record->leader,6,1);
                  #Check for config file handle to match format, else load one up! 
                  switch ($formatCode) {
                           case "a"    {$fName='bibliographic_bl.txt';}
                           case "g"    {$fName='bibliographic_bl.txt';}
                           case /[ji]/ {$fName='bibliographic_bl.txt';}
                           case "e"    {$fName='bibliographic_bl.txt';}
                           case "t"    {$fName='bibliographic_bl.txt';}
                           case "m"    {$fName='bibliographic_bl.txt';}
                  }
                  
                  my %vocab=parseCSVhoa($fName);
                  binmode $outputFile, ":utf8";
                  # Output a complete graph for this record based on format and record
                  
                 
                  print $outputFile genGraph($record,\%vocab,$formatCode);
                 
                           
                  $count++;
                  
         
         }
         };
         
         if ($@){
                  
                  print STDOUT "Dodgy record: $@\n";
                  
         }
         
        close $outputFile;
        print "$count records converted \n";

} else {
         print "Please place the MARC file you wish to process in the same directory as this script and enter its name after the script with the -f option (e.g. 'perl -f cometMarc21RDF.pl example.mrc'. Use -u to specify a URI base and -d to specify an optional id prefix for a dataset. \n";  
}

##################################
# End MAIN #######################
##################################

# genGraph master sub for marc record to graph creation ...
sub genGraph{
         
         my ($record, $vocab, $formatCode)=@_;
         my $output='';
         
         #dereferences hash
         my %vocab=%$vocab;
              
# STAGE #1 - GENERATE SUBJECT BASED ON URI PATTERN dataset qualifier and bib_id and inital triples ...
         my $subject= '<' . $uriBase . 'entry/' . $datasetId . '_' . $record->field('001')->data() . '>';
    
##########ALL THIS STUFF IS NOT RELIANT ON MAPPING FILE AND HAPPENS BY DEFAULT
         
         my $leader=$record->leader();
         
         my $field_001=$record->field('001');
         if ($field_001){
                  $field_001=$field_001->data();
         }
         
         my $field_007=$record->field('007');
         if ($field_007){
                  $field_007=$field_007->data();
         }
         
         my $field_008=$record->field('008');
         if ($field_008){
                  $field_008=$field_008->data();
         }
         #NB already have format code
         my $bibLevel = substr($record->leader,7,1);
    
    #handles what material is, using format code and bib level from leader
         #BIBO mappings
=head
         if ($formatCode=~/[agji]/){
                  
                  $output .= qq($subject \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://purl.org/ontology/bibo/Book>. \n);
                  
                  
         }
         if ($formatCode=~/[agjims]/){
                  
                  $output .= qq($subject \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://purl.org/ontology/bibo/Document>. \n);
                  
         }
         
         if ($formatCode=~/[dfpt]/){
                  
                  $output .= qq($subject \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://purl.org/ontology/bibo/Manuscript>. \n);
                  
                  
         }
         if ($formatCode=~/[e]/){
                  
                  $output .= qq($subject \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://purl.org/ontology/bibo/Map>. \n);
         }
         if ($formatCode=~/[s]/){
                  
                  $output .= qq($subject \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://purl.org/ontology/bibo/Journal>. \n);  
         }
=cut    
         #BL with Bibo mappings
         if ($formatCode=~/[at]/){
                  $output .= qq($textNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "text". \n);
                  $output.=qq($textNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/bibo/Document>. \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $textNode. \n);

         }
         if ($formatCode=~/[dfpt]/){
                  $output .= qq($manuscriptNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "manuscript". \n);
                  $output.=qq($manuscriptNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/bibo/Manuscript>. \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $manuscriptNode. \n);
         }
         if ($bibLevel=~/[am]/){
                  $output.= qq($monographNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "monographic". \n);
                  $output.=qq($monographNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/bibo/Book>. \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $monographNode. \n);
         }
         if ($bibLevel=~/[bis]/){
                  $output.= qq($continuingNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "continuing". \n);
                  $output.= qq($continuingNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/bibo/Journal>. \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $continuingNode. \n);
         }
         if ($bibLevel=~/c/){
                  $output.= qq($collectionNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "collection". \n);
                  $output.=qq($collectionNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/bibo/Collection>. \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $collectionNode. \n);
         }
         
         #non-BL
                  
         if ($formatCode=~/[g]/){
                  $output .= qq($videoNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "video". \n);
                  $output.=qq($videoNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/bibo/AudioVisualDocument>. \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $videoNode. \n);
                  
         }
         if ($formatCode=~/[ji]/){
                  
                  $output .= qq($musicNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "music". \n);
                  $output.= qq($musicNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/bibo/Document>. \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $musicNode. \n);
                  
         }
         if ($formatCode=~/[e]/){
                  $output .= qq($mapNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "map". \n);
                  $output.=qq($mapNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/ontology/bibo/Map>. \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $mapNode. \n);
                  
         }

         if ($formatCode=~/[m]/){
                  $output .= qq($softwareNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "software". \n);
                  $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $softwareNode. \n);
                  
         }
         
         #bib id as identifier
         if ($field_001){
                  
                  
                  my $identifier="UkCU".$field_001;
                  
                  $output.= qq($subject \t <http://purl.org/dc/terms/identifier> "$identifier". \n);
                  
         }
    
         #007 stuff
         
         if ($field_007){
                  
                  my $category=substr($field_007, 0, 1);
                  my $designator=substr($field_007, 1, 1);
                  
                  if ($category eq "h" && $designator eq "d"){
                           
                           $output .= qq($microfilmNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "microfilm reel". \n);
                           $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $microfilmNode. \n);
                           
                  }
                  elsif ($category eq "h" && $designator eq "e"){
                           
                           $output .= qq($microficheNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "microfiche". \n);
                           $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $microficheNode. \n);
                           
                  }
                  elsif ($category eq "h" && $designator eq "|"){
                           
                           $output .= qq($microformNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "microform". \n);
                           $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $microformNode. \n);
                           
                  }
                  
         }
         
         #008 stuff
         
         if ($field_008){
                  
                  #dates
                  my $type_of_date=substr($field_008, 6, 1);
                  my $date1=substr($field_008, 7, 4);
                  my $date2=substr($field_008, 11, 4);
                  
                  #created or issued?
                  my $cr_iss;
                  
                  if ($formatCode=~/[dfpt]/){
                           
                           $cr_iss="created";
                           
                  }else{
                           
                           $cr_iss="issued";
                           
                  }
                  
                  ##s and r not in BL mapping - why?
                  #single date (not complicated)
                  if ($type_of_date=~/[s]/){
                           
                           $output.=qq($subject \t <http://purl.org/dc/terms/$cr_iss> \t "$date1". \n);
                           
                           
                  }
                  #reprint date - takes original date as issue
                  elsif ($type_of_date=~/[r]/){
                           
                           $output.=qq($subject \t <http://purl.org/dc/terms/$cr_iss> \t "$date2". \n);
                           
                  }
                  #detailed date
                  elsif ($type_of_date=~/[e]/){
                           
                           $output.=qq($subject \t <http://purl.org/dc/terms/$cr_iss> \t "$date1.$date2". \n);
                           
                  }
                  #copyright dates
                  elsif ($type_of_date=~/[t]/){
                           
                           $output.=qq($subject \t <http://purl.org/dc/terms/dateCopyrighted> \t "$date1". \n);
                           
                  }
                  #interval dates
                  elsif ($type_of_date=~/[cdikmqu]/){
                           
                           $output.=qq($intervalNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://www.w3.org/2006/time#Interval>. \n);
                           $output.=qq($instantNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://www.w3.org/2006/time#Instant>. \n);
                           $output.=qq($instantNode \t <http://www.w3.org/2006/time#inXSDDateTime> \t "$date1". \n);
                           $output.=qq($intervalNode \t <http://www.w3.org/2006/time#hasBeginning> \t $instantNode. \n);
                           $output.=qq($instantNode \t <http://www.w3.org/2006/time#inXSDDateTime> \t "$date2". \n);
                           $output.=qq($intervalNode \t <http://www.w3.org/2006/time#hasEnd> \t $instantNode. \n);
                           $output.=qq($subject \t <http://purl.org/dc/elements/1.1/date> \t $intervalNode. \n);
                  }
                  
                  #electronic? in a diff place depending on material
                  my $form_of_item;
                  
                  if ($formatCode=~/[acdpt]/){
                           
                           $form_of_item=substr($field_008, 23, 1);
                           
                  }
                  elsif ($formatCode=~/[efgk]/){
                           
                           $form_of_item=substr($field_008, 29, 1);
                           
                  }
                  
                  if ($form_of_item eq "s"){
                           
                           $output .= qq($electronicNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "electronic". \n);
                           $output .= qq($subject \t <http://purl.org/dc/terms/type> \t $electronicNode. \n);
                           
                  }
                  
         }
         
         #FROM HERE ON IN, IT'S ALL TO DO WITH THE MAPPINGS
         #GET A LIST OF FIELDS IN THE RECORD
    
         my @fields=$record->fields();
    
         
    
         foreach my $field(@fields){
                  
                  my $tag=$field->tag();
         
                  #hack to get around no mapping for 490 if 800, 810, 811 or 830 exists
                  if ($tag eq "490"){
                           
                           my $field_800=$record->field('800');
                           my @fields_81X=$record->field('81.');
                           my $field_830=$record->field('830');
                           
                           if ($field_800||@fields_81X||$field_830){
                                    
                                    next;
                                    
                           }
                  }
                  
                  #and now on with the show!
                  my @subfieldsPredicates;
                  #is this tag in the config file?
                  if (exists $vocab{$tag}){
                  
                           @subfieldsPredicates=@{$vocab{$tag}};
                           
                  }
                  #is this a mapped field? - if not, ignore
                  foreach my $subfieldsPredicate(@subfieldsPredicates){
                   
                           #split mapping string into constituent parts
                           my ($subfields, $predicate, $type)=split(/\|/, $subfieldsPredicate);
                           
                           #expands predicate with namespace
                           my $predicate_prefix;
                           my $predicate_suffix;
                           my $namespace_prefix;
                           
                           if ($predicate=~/^(.+?):(.+)$/){
                                    
                                    $predicate_prefix=$1;
                                    $predicate_suffix=$2;
                                    
                                    $namespace_prefix=$nameSpace{$predicate_prefix};
                                    
                                    
                                    $predicate='<'.clean($namespace_prefix).'/'.clean($predicate_suffix). '>';
                                    
                           }else{
                                    
                                    #print LOG "Predicate namespace not found\n";
                                    
                           }
                           
                           #and uses type to send off the field to the right sub
                           if ($type eq "P"){
                           
                                    $output .= genPersonGraph($subject, $field, $subfields, $predicate);
                                    
                           }
                           elsif ($type eq "I"){
                            
                                    $output .= genInstitutionGraph($subject, $field, $subfields, $predicate);
                                    
                           }
                           elsif ($type eq "C"){
                            
                                    $output .= genConferenceGraph($subject, $field, $subfields, $predicate);
                                    
                           }
                           elsif ($type eq "L"){
                                    #BL don't seem to do this - why?
                                    $output .= genLanguageGraph($subject, $field, $subfields, $predicate);
                                    
                           }
                           elsif ($type eq "X"){
                                    #BL don't seem to do this - why?
                                    $output .= genCountryGraph($subject, $field, $subfields, $predicate);
                                    
                           }
                           elsif ($type eq "S"){
                                    
                                    $output .= genSubjectGraph($subject, $field, $subfields, $predicate);
                                    
                           }elsif ($type eq "D"){
                                    
                                    $output .= genDeweyGraph($subject, $field, $subfields, $predicate);
                                    
                           }
                           elsif ($type eq "R"){
                                    
                                    $output .= genLabelGraph($subject, $field, $subfields, $predicate);
                                    
                           }else{
                                    
                                    $output .= genGenericTriple($subject, $field, $subfields, $predicate);
                           
                           }
                  }        
         }#foreach marc field
         
         return $output;
         
}

#for fields without specific requirements
#i.e. straight text
sub genGenericTriple {
         
         my ($subject, $field, $subfields, $predicate)=@_;
         
         my $output;
         
         my $object;
         
         if ($subfields) {
          # multiple subfields can be lumped together ...'abh' 
                  $object = $field->as_string($subfields);
         } else {
           # Take the lot I guess ...
                  $object = $field->as_string();
         }
         
         #little hack to put prefixes on isbns and issns
         #is there a nicer way to do this?
         my $tag=$field->tag();
         if ($tag eq '020' && $predicate=~/identifier/){
                  
                  $object='urn:isbn:'.$object;
         }
         elsif ($tag eq '022'){
                  
                  $object='urn:issn:'.$object;
                  
         }
         #and another one to sort out 856s with second indicator 1 or 2
         my $ind2=$field->indicator(2);
      # if ($tag eq '856'&&$ind2!=0){
         if ($tag eq '856'&&$ind2 ne '0'){          
                  $predicate="<http://www.w3.org/2000/01/rdf-schema#seeAlso>";    
         }
         
         # Finally, if we got anything back - generate a triple
         if ($object){
                  #gets rid of non-digit stuff from date??
                  #NOT USED?
                  if ($predicate=~/\#date/) {
                           $object =~s/\D//g;
                  }
             
                  # Extra cleanup clauses here for dates, and maybe a few others to strip punctuation ...
                  $object=trim($object);
                  $output .= "$subject \t $predicate \t \"" . clean($object) . "\" .\n";  
                
         }

          
         return $output;
}

#for triples which require RDF english language labels
#i.e. potentially controlled vocabularies?
sub genLabelGraph {
         
         my ($subject, $field, $subfields, $predicate)=@_;
         
         my $output;
         
         my $object;
         
         if ($subfields) {
          # multiple subfields can be lumped together ...'abh' 
                  $object = $field->as_string($subfields);
         } else {
           # Take the lot I guess ...
                  $object = $field->as_string();
         }
         #clears whitespace and trailing punctuation
         $object=trim($object);
         
         my $lNode= '<' . $uriBase . 'entity/' . $datasetId . '_' . genGuidString($object) . '>';
         #strips dodgy characters
         $object=clean($object);
        
         $output .= qq($lNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "$object". \n);
         #and this goes on the end of it all!
         $output .= qq($subject \t $predicate \t $lNode. \n);
         
         return  $output;
}# end sub


#sub for country codes
sub genCountryGraph {

         my ($subject, $field, $subfields, $predicate)=@_;
         
         my $output='';         
         
         my $countryCode=substr($field->data(),15,3);
         
         if ($countryCode) {
                  
                  $countryCode=trim($countryCode);
                  $countryCode=clean($countryCode);
                  
                  # Again no need for a blank node, can assume URI ...
                  my $countryURI = '<http://id.loc.gov/vocabulary/countries/' . $countryCode . '>';
                  
                  $output.="$countryURI \t <http://www.w3.org/2004/02/skos/core#inScheme>  \t <http://id.loc.gov/vocabulary/countries>.\n";   
                   $output.="$countryURI \t <http://www.w3.org/2004/02/skos/core#notation> \t" . '"' .$countryCode .'"^^<http://www.w3.org/2001/XMLSchema#string>' .".\n";
                  
                   $output .= $subject . "\t" . '<http://RDVocab.info/ElementsplaceOfPublication>'  . "\t" . $countryURI  . ".\n";
         }
         #TODO - look up against GEOnames
         #_:bnode1154381376 <http://RDVocab.info/ElementsplaceOfPublication> <http://sws.geonames.org/6269131/>.
return $output;
}

#sub for language
#BL seem to prefer 041 $a for this - why?
sub genLanguageGraph {

         my ($subject, $field, $subfields, $predicate)=@_;
         
         my $output='';         
         
         my $langCode=substr($field->data(),35,3);
         
         if ($langCode) {
                  
                  $langCode=trim($langCode);
                  $langCode=clean($langCode);
         
             #No need for blank nodes, we can assume a URI based on LOC being nice to us ...
                  my $langURI = '<http://id.loc.gov/vocabulary/iso639-2/' . $langCode . '>';

                  $output .= "$langURI \t <http://www.w3.org/2004/02/skos/core#inScheme> \t <http://id.loc.gov/vocabulary/iso639-2>. \n";  
                  $output .= "$langURI \t <http://www.w3.org/2004/02/skos/core#notation>\t" . '"' .$langCode .'"^^<http://www.w3.org/2001/XMLSchema#string>' .".\n";
                  
                  $output .= "$langURI \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://www.w3.org/2004/02/skos/core#Concept>"   . ".\n";  
                  $output .= "$subject \t <http://purl.org/dc/terms/language> \t $langURI .\n";       
         }
         
         return $output;
}

#sub for people
sub genPersonGraph {
         
         my ($subject, $field, $subfields, $predicate)=@_;         
         my $output='';
         my $object;
         
         #little hack to cope with different setup for 700s with $t
         #which are treated as relation, not contributor
         my $subfield_t=$field->subfield('t');
         
         if ($predicate=~/contributor/&&$subfield_t){
                  
                  return;
                  
         }
         if ($predicate=~/relation/&&!$subfield_t){
                  
                  return;
                  
         }
         
        
         #except where $t is present, subfield settings should mean this
         #gives the authorised form
         my $personName;
         
         if ($subfields){
                  
                  $personName=$field->as_string($subfields);        
                  
         }else{
                  $personName=$field->as_string();   
         }
        
         
         $personName=trim($personName);
        
         my $pNode= '<' . $uriBase . 'entity/' . $datasetId . '_' . genGuidString($personName) . '>';
        
         
         
         #this bit is local to Cambridge
         #Not done by BL
         $output .= $pNode . "\t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://xmlns.com/foaf/0.1/Person>. \n";
                                    
         my $dates = $field->subfield('d');
         my ($birthDate,$deathDate);
         
         if ($dates) {
                  
                  #first of all, get rid of ca. and fl. which aren't real birth or death dates
                  if ($dates=~/fl\.|ca\./){
                           
                           #do nothing
                           
                  }
                  #otherwise, if date contains a hyphen, assume range
                  #but fix also works for unterminated dates?
                  elsif ($dates=~/\-/) {
                           
                           my @dates=split(/\-/,$dates);
                           $birthDate =  trim($dates[0]);
                           
                           if ($dates[1]) {
                                    $deathDate = trim($dates[1]);
                           }
                           
    #No Hyphen - assume single date - look for definitive birth event with a 'd' ...
                  } elsif ($dates=~/\b\./) {
                           
                           $birthDate = trim($dates);
                           
    # - look for definitive death event with a 'd' ...
                  } elsif ($dates=~/\d\./) {
                           
                           $deathDate = trim($dates);
    # Final assumption for authors with recorded dates but with single date no hyphen. Assume its a birthdate?
                  } else {
                           $birthDate = trim($dates);
                  }
    # produce output for dates ...
                  if ($birthDate) {
        #my $bNode = '_:bnode'  .  genGuidString($birthDate);
                           $birthDate =~ s/\D//g;
                           $birthDate=clean($birthDate);
                           my $bNode = '<' . $uriBase . 'entry/' . $datasetId . '_' . genGuidString($birthDate.$personName) . '>';
                           $output .= "$bNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://purl.org/vocab/bio/0.1/Birth>. \n";     
                           $output .= "$bNode \t <http://purl.org/vocab/bio/0.1/date> \t \"" . $birthDate . "-01-01T00:00:00Z" . "\".\n";
                           $output .= "$pNode \t <http://purl.org/vocab/bio/0.1/event> \t   $bNode .\n"; 
                  }
        
        
                  if ($deathDate) {
        #my $dNode = '_:dnode'  .  genGuidString($deathDate);
                           $deathDate =~ s/\D//g;
                           $deathDate=clean($deathDate);
                           my $dNode = '<' . $uriBase . 'entry/' . $datasetId . '_' . genGuidString($deathDate.$personName) . '>';
                           
                           $output .= "$dNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://purl.org/vocab/bio/0.1/Death>. \n";
          # TODO FIX TYPE PREDICATE FOR DATE ....
                           $output .= "$dNode \t <http://purl.org/vocab/bio/0.1/date> \t \"" . $deathDate . "-01-01T00:00:00Z" . "\".\n";
                           $output .= "$pNode \t <http://purl.org/vocab/bio/0.1/event> \t   $dNode .\n"; 
                  }
                  
         }#end of if $dates             
                           
         # Finally output skos notation, foaf and link person graph to record graph
         #$output .= $pNode . "\t <http://www.w3.org/2004/02/skos/core#notation> \t \"$personFull\".\n";
         
         $personName=clean($personName);
         
         $output .= $pNode . "\t <http://xmlns.com/foaf/0.1#name> \t \"$personName\".\n";

         #and this bit is how the BL handles it
         #will this clash??
         $output .= qq($pNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "$personName". \n);
         
         #and this goes on the end of it all!
         $output .= qq($subject \t $predicate \t $pNode. \n);
         
         #if there is a title attached to the name
         #new and experimental!!
         if ($subfield_t){
                  
                  #get the title out as a separate string
                  my $title=$field->as_string('fhklmnoprst');
                  #trim it
                  $title=trim($title);
                  #the node for the title will have to include the person
                  #to disambiguate identical titles with diff authors - i.e. "Poems"
                  my $person_title=$personName.$title;
                  #generate a node for the title
                  my $tNode= '<' . $uriBase . 'entity/' . $datasetId . '_' . genGuidString($person_title) . '>';
                  #clean the title
                  $title=clean($title);
                  #label the node with the title
                  $output .= qq($tNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "$title". \n);
                  #link to the base entity (work)
                  $output .= qq($subject \t $predicate \t $tNode. \n);
                  #say that the person is the author of the title(?)
                  $output .= qq($tNode \t <http://purl.org/dc/terms/creator> \t $pNode. \n);
                  
         }
         
         return  $output;
}# end sub

#sub for institutions
sub genInstitutionGraph {
         
         my ($subject, $field, $subfields, $predicate)=@_;
         
         my $output;
         
         my $object;
         
         #little hack to cope with different setup for 710s with $t
         #which are treated as relation, not contributor
         my $subfield_t=$field->subfield('t');
         if ($predicate=~/contributor/&&$subfield_t){
                  
                  return;
                  
         }
         if ($predicate=~/relation/&&!$subfield_t){
                  
                  return;
                  
         }

         
         if ($subfields) {
          # multiple subfields can be lumped together ...'abh' 
                  $object = $field->as_string($subfields);
         } else {
           # Take the lot I guess ...
                  $object = $field->as_string();
         }
         
         $object=trim($object);
        
         my $iNode= '<' . $uriBase . 'entity/' . $datasetId . '_' . genGuidString($object) . '>';
        
         $object=clean($object);
         
         $output .= qq($iNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "$object". \n);
         #and this goes on the end of it all!
         $output .= qq($subject \t $predicate \t $iNode. \n);
         
         return  $output;
}# end sub

#sub for conferences
#same as institutions, for now!
sub genConferenceGraph {
         
         my ($subject, $field, $subfields, $predicate)=@_;
         
         my $output;
         
         my $object;
         

         #little hack to cope with different setup for 711s with $t
         #which are treated as relation, not contributor
         my $subfield_t=$field->subfield('t');
         if ($predicate=~/contributor/&&$subfield_t){
                  
                  return;
                  
         }
         if ($predicate=~/relation/&&!$subfield_t){
                  
                  return;
                  
         }


         if ($subfields) {
          # multiple subfields can be lumped together ...'abh' 
                  $object = $field->as_string($subfields);
         } else {
           # Take the lot I guess ...
                  $object = $field->as_string();
         }
         
         $object=trim($object);
        
         my $iNode= '<' . $uriBase . 'entity/' . $datasetId . '_' . genGuidString($object) . '>';

         $object=clean($object);
        
         $output .= qq($iNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "$object". \n);
         #and this goes on the end of it all!
         $output .= qq($subject \t $predicate \t $iNode. \n);
         
         return  $output;
}# end sub


#sub for subjects
# So generic - what about names, places, people, time, space, the universe???
sub genSubjectGraph {
         my ($subject, $field, $subfields, $predicate)=@_;
         
         my $output;
         
         
         
         #set scheme by second indicator
         my $ind2=$field->indicator(2);

         #unless it's a 653 or a 662!
         my $tag=$field->tag();

         my $scheme;
         
         unless ($tag eq '653'||$tag eq '662'){
                  #LC         
                  if ($ind2==0){
                           
                           $scheme=qq(<http://id.loc.gov/authorities#conceptScheme>);         
                  }
                  #MESH
                  elsif ($ind2==2){
                           
                           
                           $scheme=qq(<http://www.nlm.nih.gov/mesh>);
                           
                  }
         
         }
         
         my $subjectField;
         
         if ($subfields){
                  
                  $subjectField=$field->as_string($subfields);
                  
         }else{
         #if no subfields passed (i.e. process all subfields), create a subject-specific string
                  
                  $subjectField=$field->as_string('a b c d e f h j k l m n o p q r s t');
         
                  # additional clauses for qualifiers
                  if ($field->subfield('v')) {
                     $subjectField .= " -- " . $field->subfield('v');       
                  }
                  if ($field->subfield('x')) {
                    $subjectField .= " -- " . $field->subfield('x');       
                  }
                  if ($field->subfield('y')) {
                    $subjectField .= " -- " . $field->subfield('y');       
                  }
                  if ($field->subfield('z')) {
                    $subjectField .= " -- " . $field->subfield('z');       
                  }
         
         }
         
         $subjectField=trim($subjectField);
         
         #and now on with the show
                  
         my $sNode = '<' . $uriBase . 'entry/' . $datasetId . '_' . genGuidString($subjectField) . '>';
         
         $subjectField=clean($subjectField);
         
         if ($scheme){
         
                  $output .=qq($sNode \t <http://www.w3.org/2004/02/skos/core#inScheme> \t $scheme. \n);
                  # just present it as a label - no link to LOC entry for now ...
                  $output .=qq($sNode \t <http://www.w3.org/2004/02/skos/core#prefLabel> \t "$subjectField" . \n);
                  
                  # This is a concept rather than real link (#linkeddatacopout)
                  $output .= qq($sNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>\t <http://www.w3.org/2004/02/skos/core#Concept>. \n);
                  $output .= qq($subject \t $predicate \t  $sNode .\n);      
         
         }else{
                  #if no scheme, just output as straight subject with label
                  
                  $output .= qq($sNode \t <http://www.w3.org/2000/01/rdf-schema#label> \t "$subjectField". \n);
                    
                  $output .= qq($subject \t $predicate \t  $sNode .\n);
         }
                  
         return $output;
}

#sub for dewey
sub genDeweyGraph {

         my ($subject, $field, $subfields, $predicate)=@_;
         
         my $output;
         
         my $object;
         
         if ($subfields) {
          # multiple subfields can be lumped together ...'abh' 
                  $object = $field->as_string($subfields);
         } else {
           # Take the lot I guess ...
                  $object = $field->as_string();
         }
         
         $object=trim($object);
         
         my $deweyNode='<' . $uriBase . 'entry/' . $datasetId . '_' . genGuidString($object). '>';
         
         $object=clean($object);
         
         $output.=qq($deweyNode \t <http://www.w3.org/2004/02/skos/core#notation> \t "$object"^^<ddc:Notation>. \n);
         $output.=qq($deweyNode \t <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> \t <http://www.w3.org/2004/02/skos/core#Concept>. \n);
         $output.=qq($subject \t <http://purl.org/dc/terms/subject> \t $deweyNode.\n);
         
         
         return $output;
}

# Additional geographic nodes ?? Also chronological? 
#_:bnode946051648 <http://www.w3.org/2004/02/skos/core#inScheme> <http://id.loc.gov/authorities#conceptScheme>.
#_:bnode946051648 <http://www.w3.org/2004/02/skos/core#prefLabel> "Poland".
#_:bnode946051648 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2004/02/skos/core#Concept>.
#_:bnode1154381376 <http://purl.org/dc/terms/spatial> _:bnode946051648.


####################################################
# Utility subs ....
#this one parses into an array
sub parseCSV {
         
         my $file = $_[0];
         my %hash=();
         open my $fh, '<', $file or die "Cannot open: $!";
         
         while (my $line = <$fh>) {
                  $line =~ s/\s*\z//;
                  #unless it's a comment
                  unless ($line=~/^\#/){
                           
                           my ($key, $value)= split /;/, $line;
                           
                           $hash{$key} = $value;         
                           
                  }
                  
                  
         }
         close $fh;
         return %hash;
}
#this one parses into a hash of arrays
sub parseCSVhoa {
         
         my $file = $_[0];
         my %hash=();
         open my $fh, '<', $file or die "Cannot open: $!";
         
         while (my $line = <$fh>) {
                  $line =~ s/\s*\z//;
                  #unless it's a comment
                  unless($line=~/^\#/){
                           
                           my ($key, $value)= split /;/, $line;
                  
                           push @{$hash{$key}}, $value;
                           
                  }
                  
         }
         close $fh;
         return %hash;
}

sub flatten { map @$_, @_ }


sub genGuidString {
      my $string = shift;
      $string =~ s/[^a-zA-Z0-9-\s]//g;  
       return md5_hex(encode_utf8($string));    
}

sub scrubAlpha($) {
     my $string = shift;
     $string =~ s/\D//g;   
    return $string;     
}

#Generic whitespace killer,
#plus strips trailing punctuation
sub trim{
	
        my $string = shift;
        
        #strips some of the punctuation off the end
        $string=~s/[\.\;\/\:\,]$//;
         
        #and then strip any remaining whitespace
        
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	
	return $string;
}

sub clean{
         
         my $string=shift;
         
         $string=~s/([\"\t\n\\])/\\$1/g;
         
         return $string;
}
################


package Encode;
use Encode::Alias;

sub decode($$;$)
{
    my ($name,$octets,$check) = @_;
    my $altstring = $octets;
    return undef unless defined $octets;
    $octets .= '' if ref $octets;
    $check ||=0;
    my $enc = find_encoding($name);
    unless(defined $enc){
       require Carp;
       Carp::croak("Unknown encoding '$name'");
    }
    my $string;
    eval { $string = $enc->decode($octets,$check); };
    $_[1] = $octets if $check and !($check & LEAVE_SRC());
    if ($@) {
       return $altstring;
    } else {
       return $string;
    }
}