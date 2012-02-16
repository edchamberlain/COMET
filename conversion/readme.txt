# Readme for Comet Marc21 to RDF conversion scripts 0.3
#######################################################

# Written by Huw Jones, Ed Chamberlain, Cambridge Univesity Library 2011
# Produced for the Comet project funded by JISC as part of the Infrastructure for Resource Discovery funding
# All code licensed under the GPL - http://www.gnu.org/licenses/gpl.html

# Code is provided 'as is' and will not doubt require some hammering to work with local setups. - contact emc59@cam.ac.uk. 

#Requirements
#############
- Extracted Marc21
- Perl (tested on v5.85)
- The Perl Marc Record module (http://search.cpan.org/~gmcharlt/MARC-Record-2.0.3/)

#Instructions for batch tool
############################

1) Extract all bibliographic records (or those you wish to convert) from your library management system as a single marc21 batch file. Consult you library systems vendor or supporting community if you requrie assistance with extracting data.

2) Be sure to rename / move any directories or files created from a previous run that you want to keep

3) In simple mode, run the script with the following syntax 'perl marc2rdf_batch.pl XXXX.mrc with xxx.mrc being the name of the marc file

4) The script wll then run through the marc file and produce RDF triples

6) There are more complex argument options avialable:
-f input marc21/text file of identifers filename (mandatory if any advanced arguments are used)
-o output filename
-u URI preffix i.e. http://mydomain.co.uk/id - defaults to a Cambridge one (or edit in the script) - see details on our URI construction here:
http://cul-comet.blogspot.com/2011/05/metadata-and-standards-uri-construction.html
-d An additional prefix for the dataset to go in the URI string before the record identifier


5) To edit vocabulary used, edit the namespaces.txt and bibliographic_bl.txt text files to add additonal vocabs. The script can optionally load in different formats condifuration files based on marc header information

Format is Marcfield; subfield(s)|RDF vocab prefix| RDF field| mapping type

245;abnp|dcterms:title|O
#L=Language, X=Country, D=Dewey number, P=Person, I=Institution, C=Conference, R=generic triple with text label, O=Generic triple, plain text

The code has specific subroutines to create differnet graphs combinations for different fields. 

#Instructions for SQL tool
##########################

- As above and:

- Perl DBI installed, and access to your library LMS's underlying SQL database.
- You will also need a text file containing ID's of records you wish to export, with one per line.

It was written for the Voyager LMS but can hopefully be adapted for other RDBMS based systems without hopefilly too much hassle. 

1) Edit the perl script woth appropraite database connections around line 100 and provide an SQL statement to retrieve a marc blob object from a record id around 1150. 

2) Be sure to rename / move any directories or files created from a previous run that you want to keep

3) Place the text file of record ID's 

4)  Run the script with the following syntax 'perl marc2rdf_batch.pl XXXX.txt' 

5) See above documentation for more advanced options
