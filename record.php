<?php
include_once(dirname(__FILE__).'/config.php');
/*
All content negotiation handled by Apache ...
original rewrite rules ...
#disable multiview - recommended ...
Options -MultiViews -Indexes 
DirectoryIndex card.html index.html index.htm index.php index.xml

RewriteEngine on
# Generic rdf request via HTTP_ACCEPT - will resolve as RDf/XML by app at /var/www/comet/comet.php
#RewriteCond %{HTTP_ACCEPT} application/rdf$
#RewriteRule ^id(.+)/?$ record.php?uri=http://data.lib.cam.ac.uk/id/$1&format=rdf [L]

# Pick up any content request with RDF+, take what is after the + and pass that
RewriteCond %{HTTP_ACCEPT} application/rdf\+(.+)$
RewriteRule ^id/(.+)$ record.php?uri=http://data.lib.cam.ac.uk/id/$1&format=%1 [L]

# Or grab from file extension ...
RewriteCond %{REQUEST_URI} \.(.+)$
RewriteRule ^id/(.+)\..+$ record.php?uri=http://data.lib.cam.ac.uk/id/$1&format=%1 [L]

# content request for turtle ...
RewriteCond %{HTTP_ACCEPT} application/x-turtle$ 
RewriteRule ^id/(.+)/?$ record.php?uri=http://data.lib.cam.ac.uk/id/$1&format=turtle [L]

# content request for triples as plain text ...
RewriteCond %{HTTP_ACCEPT} text/plain$
RewriteRule ^id/(.+)/?$ record.php?uri=http://data.lib.cam.ac.uk/id/$1&format=nt [L]

# alternate content request for json (non-rdf) ...
RewriteCond %{HTTP_ACCEPT} application/json$
RewriteRule ^id/(.+)/?$ record.php?uri=http://data.lib.cam.ac.uk/id/$1&format=json [L]

# Main rule for uris to the web app and html view
RewriteRule ^id/(.+)/?$ record.php?uri=http://data.lib.cam.ac.uk/id/$1 [L]
*/
$uri = trim($_GET['uri'])|trim($_POST['uri']);
$format = trim($_GET['format'])|trim($_POST['format']);
if (!$format) {
  $format = 'html';
}



/* Render record */
$record = new cometDisplay;
$record->initRecord($uri, $format, $store);
?>
