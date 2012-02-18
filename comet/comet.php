<?php

/* Comet record container class - generate HTML / RDF JSON and other HTML display for machine human consumption based on ARC2. Should be portable to other rdf stores using the arc2 remoteStore class ...
// Uses the ARC2 library and the arc2 starter pack
// For best practice - use mod_rewrite to turn url structures into format parameter
// Ed Chamberlain, Cambridge University Library 2011 - funded by the JISC infrastucture for resource discovery programme
// The following code is licensed under the GPL.
// Code is provided 'as is' with no firm assurance of support or functionality. May need substantial alteration to work
*/


class cometDisplay {
         
// Draw content based on request - use mod_rewrite or equiv to generate parameter for format

public function initRecord($uri, $format, $store) {
        
        if ($result = $this->getRecord($uri,$store)) {
                    switch ($format) {
                    case ($format=='html' || $format=='htm'):
                    
                    $this->genHTMLRecord($result, $uri, $store, $triples);
                    break;
                   
                    case 'nt':
                    header('content-type: text/plain');
                     $triples =  $this->genTriples($result, $uri, $store);
                    print  utf8_encode($store->toNTriples($triples));
                    break;
                  
                    case ($format=='json' || $format=='js'): 
                    header('content-type: application/rdf+json');
                     $triples =  $this->genTriples($result, $uri, $store);
                    print  utf8_encode($store->toRDFJSON($triples));
                    break;
                     
                    case ($format=='xml' || $format=='rdf'):
                    header('content-type: application/rdf+xml');
                     $triples =  $this->genTriples($result, $uri, $store);
                    print  $store->toRDFXML($triples);
                    break;
                  
                    case ($format=='turtle' || $format=='ttl'):
                    header('content-type: application/x-turtle');
                     $triples =  $this->genTriples($result, $uri, $store);
                    print  utf8_encode($store->toTurtle($triples));
                    break;
                  }
        } else {
           header("Status: 404 Not Found");
           $this->genHTMLRecord($result, $uri, $store, $triples);
        }
}


## Grabs resutls and calls HTML generation for linked results page
public function initLinkedResultsFull($uri, $store) {
    $results = $this->getLinkedResultsFull($uri, $store);
    $this->genHTMLResultsFull($results, $uri);
}


# Returns an array structure for a complete bib record from a URI
public function getRecord($uri,$store) {
    return $store->query("SELECT * WHERE {
         { '$uri' ?p ?o . }
         }"
         ,'rows');
    }
    

    
## Returns URI's and titles of all records linked to a subject/creator URI ....
 public function getLinkedResultsFull($uri, $store) {
        return $store->query("     
        PREFIX  dc: <http://purl.org/dc/terms/>
        CONSTRUCT {
        ?s ?p ?t
        }WHERE { 
        ?s ?p <$uri> . 
        ?s dc:title ?t 
        } LIMIT 1000
         ");
        
    }   
    
# Retrives over-arching graph from URI     
public function getGraph($uri, $store) {
        return $store->query("SELECT ?g WHERE {
  GRAPH ?g { <$uri> ?p ?o . }
}
LIMIT 1"
         ,'rows');     
    }    
  
# Retrives license from URI  
public function getLicenses($uri, $store) {
        return $store->query("SELECT ?o WHERE {
  { <$uri> <http://purl.org/dc/terms/license> ?o . }
}"
         ,'rows');     
    }     
    
    

# Gets label for a URI Really ugly sub, cannot seem to do in SPARQL with optional ...
public function getLabel($uri, $store) {    
     if ($return = $store->query("SELECT ?o WHERE 
  { <$uri> <http://www.w3.org/2000/01/rdf-schema#label> ?o . 
}",'rows')) {
     return $return;
    
    }elseif($return = $store->query("SELECT ?o WHERE 
  { <$uri> <http://www.w3.org/2004/02/skos/core#prefLabel> ?o . 
}",'rows')) {
      return $return;   
    }
}



# Invesrse of above - takes a label and looks for a URI ...
public function  getURIfromLabel($label, $store) {
     if ($results = $store->query("SELECT ?u WHERE 
  { ?u <http://www.w3.org/2000/01/rdf-schema#label> '$label' . 
}",'rows')) {
     $uri = $results[0]['u'];  
    
    }elseif($results = $store->query("SELECT ?u WHERE 
  { ?u <http://www.w3.org/2004/02/skos/core#prefLabel>  '$label' . 
}",'rows')) {
      $uri = $results[0]['u'];  
    }
return $uri;
}
     
     
     

# Key sub, generates internal triple data structure from a URI - expandes into two layers of linking, i.e. creator and creators' death dates ...
public function genTriples($result, $uri, $store) {
    
   $url= parse_url($uri);
   $uriBase = 'http://' .$url['host'];
   $output='';
  // print $uriBase;
        // For all non HTML formats - expand triple to cover linked graphs from this domain...
        foreach ($result as $row) {
           $p = $row["p"];
           $o = $row["o"];
          // Hard coded hack ... want to include 2nd tier of internal entries - rewrite as SPARQL
          if ($this->string_begins_with($o,$uriBase)){
              $intResult = $this->getRecord($o,$store);
                  foreach ($intResult as $intRow) {
                       $ip = $intRow["p"];
                       $io = $intRow["o"];
                      
                      if ($this->string_begins_with($io,$uriBase)){          
                   // Repace this hack with some neater SPARQL?  
                       $intResult = $this->getRecord($io,$store);
                      foreach ($intResult as $intRow) {
                       $iip = $intRow["p"];
                       $iio = $intRow["o"];
               $output .= "<$io> \t ". $this->uriOrString($iip,'triple') . "\t" . $this->uriOrString($iio,'triple') ."." . PHP_EOL; 
                         }
                      }
            $output .= "<$o> \t ". $this->uriOrString($ip,'triple') . "\t" . $this->uriOrString($io,'triple') ."." . PHP_EOL;    
                   }
            }
         $output .= "<$uri> \t ". $this->uriOrString($p,'triple') . "\t" . $this->uriOrString($o,'triple') ."." . PHP_EOL;  
        }
        
        # Provide a specific link and license reference to parent graph for dataset ...
        $graph=$this->getGraph($uri, $store);
        $graphUri = $graph[0]["g"];
        $output .= "<$uri> \t ". '<http://purl.org/dc/terms/isPartOf>' . "\t" . $this->uriOrString($graphUri,'triple') ."." . PHP_EOL;  
        
        
        # Then grab any licenses or attached to that graph
        $licenses=$this->getLicenses($graphUri, $store);
        foreach ($licenses as $license) {
          $lo = $license["o"];   
        $output .= "<$graphUri> \t ". '<http://purl.org/dc/terms/license>' . "\t" . $this->uriOrString($lo,'triple') ."." . PHP_EOL;      
        }
      
      $formatsArray = array("rdf", "html", "nt", "js", "n3");
        
        foreach ($formatsArray as $format) {
        $output .= "<$uri> \t <http://purl.org/dc/terms/hasFormat> \t <$uri.$format>" .".". PHP_EOL;    ;    
        }
        
        $parser = ARC2::getRDFParser();
        $parser->parse($uri,$output);
        $triples = $parser->getTriples();
        
        return $triples;
        // print $triples;
}

# Not currently used - turns internal triple format into .dot source for visualisation ....
public function genTriplesVizual($triples, $format) {
     $output ='';
     $config = array(
        /* path to dot */
        'graphviz_path' => '/usr/local/bin/dot',
        /* tmp dir (default: '/tmp/') */
        'graphviz_temp' => '/var/www/tmp/',
        /* pre-defined namespace prefixes (optional) */
        'ns' => array('foaf' => 'http://xmlns.com/foaf/0.1/',
                      'dc' => 'http://purl.org/dc/terms/'
                      )
      );

      $viz = ARC2::getComponent('TriplesVisualizerPlugin', $config);
      switch ($format) {
        /* display an  svg embed  */
        case 'svg':
        $svg = $viz->draw($triples, 'svg', 'base64');
        //$output = '<embed type="image/svg+xml" src="data:image/svg+xml;base64,' . $svg . '"/>';
        $output = $svg;
        break;
       
        /* display a png image */
        case 'png':
        $png = $viz->draw($triples, 'png', 'base64');
        $output = '<img src="data:image/png;base64,' . $png . '"/>';
        break;
       
        /* generate a dot file */
        case 'dot':
        $output = $viz->dot($triples);
        break;
      }
//print var_dump($viz->getErrors());
      
return $output;
}


## Grab data and generate HTML results page
public function genHTMLResultsFull($results, $uri) {
  $this->genHTMLHeader();
  $this->genHTMLResultsDisplayFull($results, $uri);
  $this->genHTMLFooter();
}


# Grab data and assemble full HTML page 
public function genHTMLRecord($result, $uri, $store, $triples) {
  $this->genHTMLHeader();
  $this->genHTMLRecordDisplay($result, $uri, $store, $triples);
  $this->genHTMLFooter();
}


// HTML page header 
public function  genHTMLHeader() {
    print '<!DOCTYPE html>
    <html>
    <head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/> 
    <title>library open data site</title>';
      include 'includes/css.php'; 
     
     print '</head><body class="home"><div class="container">';
     include 'includes/header.php'; 
}
   

###### Generate HTML results display to show relationships between records 
     public function genHTMLResultsDisplayFull($results, $uri) {
        
      print '<div class="grid_20">';

      if ($results) {
         asort($results);
          print "<br/><h5>Entries that link to: $uri </h5><br/>";    
            foreach ($results['result'] as $resultURI=>$result) {
           
           print "<p><a href=\"$resultURI\">$resultURI</a> <br/>";
                     foreach ($result as $resultKey=>$resultValue) {
                      #  var_dump($resultValue);
                        $title = $resultValue[0]['value'];
                        print "Linked as: <a href=\"$resultKey\">$resultKey</a></br/>";
                     }
           
              print "(Title: <i> $title</i>)</p>";
           }

          print "<hr/>";
          
           print "<h5>SPARQL used behind this page:</h5>";
           print '<form id="sparql-form" action="endpoint.php"  enctype="application/x-www-form-urlencoded" method="get">';
           print '<textarea id="query" name="query" class="embeddedQuery" rows="2" cols="30" 1000px style="border: 2px solid #cccccc; height: 120px; width: 450px">';
           print "PREFIX  dc: <http://purl.org/dc/terms/>
        CONSTRUCT {
        ?s ?p ?t
        }WHERE { 
        ?s ?p <$uri> . 
        ?s dc:title ?t 
        } LIMIT 1000";
           print '</textarea>';
           print '<input type="submit" value="Try query" style="border: 2px solid #cccccc; margin-left: 5px;" />';
           print '<input type="hidden" id="output" name="output" value="htmltab" />';
           print '<input type="hidden" id="show_inline" name="show_inline" value="1" />';
           print '</form></div>';
       
      }
} 
     

# Generate HTML for main body page ...     
public function  genHTMLRecordDisplay($result, $uri, $store, $triples) {
  print '<div class="container">';
    
      if ($result) {
        


          print "<table class=\"record \">";
         
          print "<tr><th colspan=\"2\">Entries for <a href='$uri'>$uri</a> as a subject:</th></tr>";
          print "<tr><th>Predicate</th><th>Object</th></tr>";
      
        $bib ='N';
      
          foreach ($result as $row) {
              $p = $row["p"];
              $o = $row["o"];
      
              // Check data for flags to look for anything that will not link easily to non RDF services ...
              if ($p=="http://purl.org/dc/terms/title") {
                  $bib='Y';
              }
              
              if (strpos($o, "http://www.w3.org/1999/02/22-rdf-syntax-ns#_") !== 0) {
                  print "<tr><td>";
                  print $this->uriOrString($p,'link');
                  print "</td>";
                  
                  print "<td>";
                  print $this->uriOrString($o,'link');
                    if ($this->string_begins_with(htmlspecialchars($o),'http://')) {
                      $labels = $this->getLabel($o, $store);
                      #var_dump($labels);
                      if ($labels) {
                        print "<br/>label: <i>" . $labels[0]['o'] . '</i>';
                      }
                    }
                  
                  print "</td></tr>";
              }
          }
          print "</table>";
         
          if ($bib=='Y') {
               print "<hr/>";
               
                $graph=$this->getGraph($uri, $store);
                 $graphUri = $graph[0]["g"];
                 print "<h5>License information:</h5><p>This record belongs to the dataset described at <a href=\"$graphUri\">$graphUri</a> which has the
                 following license(s) attached:</p><ul>";
                 
                # Then grab any licenses or attached to that graph ...
                
                $licenses=$this->getLicenses($graphUri, $store);
                foreach ($licenses as $license) {
                     $lo = $license["o"];   
                     print "<li><a href=\"$lo\">$lo</a></li>";
                 }
                print "</ul>";  
           }
          
          print "<hr/>";
          
           print "<h5>SPARQL used behind this page:</h5>";
           print '<form id="sparql-form" action="endpoint.php"  enctype="application/x-www-form-urlencoded" method="get">';
           print '<textarea id="query" name="query" class="embeddedQuery" rows="2" cols="30" 1000px style="border: 2px solid #cccccc; height: 120px; width: 450px">';
           print "SELECT * WHERE { '$uri' ?p ?o . }";
           print '</textarea>';
           print '<input type="submit" value="Try query" style="border: 2px solid #cccccc; margin-left: 5px;" />';
           print '<input type="hidden" id="show_inline" name="show_inline" value="1" />';
           print '<input type="hidden" id="output" name="output" value="htmltab" />';
           print '</form>';
        
             
          print '</div>';
          print '<div>';
          print "<br/><p><b>RDF formats:</b></p><ul>";
          print '<li><a href="'. $uri.'.nt">triples (nt)</a></li>';
          print '<li><a href="'. $uri.'.json">RDF/JSON</a></li>';
          print '<li><a href="'. $uri.'.rdf">RDF/XML</a></li>';
          print '<li><a href="'. $uri.'.ttl">turtle</a></li>';
          print '</ul>';
          
                        // Pull out UL Voyager bib_id for other services ...
                    preg_match('/\d+$/', $uri, $matches);
                    $bibid=$matches[0];
                      /*
                      if ($bib=='Y') {
                      print "<p><b>Non-RDF formats for this record:</b></p><ul>";
                      print '<li><a href="http://www.lib.cam.ac.uk/api/voyager/bibData.cgi?database=cambrdgedb&bib_id='.$bibid.'&format=xml">XML (not RDF)</a></li>';
                      print '<li><a href="http://www.lib.cam.ac.uk/api/voyager/bibData.cgi?database=cambrdgedb&bib_id='.$bibid.'&format=json">JSON (not RDF)</a></li>';
                      print '<li><a href="http://search.lib.cam.ac.uk/export.ashx?type=export-ris&file=export.ris&itemid=%7ccambrdgedb%7c'.$bibid.'">RIS</a></li>';
                      print '<li><a href="http://www.lib.cam.ac.uk/ab_support/bibtex.php?itemid=%7ccambrdgedb%7c'.$bibid.'">BibTex</a></li>';
                      print '<li>View and interact with the catalogue record in the <a href="http://hooke.lib.cam.ac.uk/cgi-bin/bib_seek.cgi?cat=ul&bib='.$bibid . '">Newton</a> and <a href="http://search.lib.cam.ac.uk/?itemid=|cambrdgedb|'.$bibid . ' ">LibrarySearch</a>.</li>';
                       print '</ul>';
                       } else {
                      // print '<p><a href="/endpoint.php?query=SELECT+*+WHERE+{%0D%0A++{+%3Fs+%3Fp+<' . $uri. '>+.+}%0D%0A}%0D%0ALIMIT+1000&output=htmltab&jsonp=&key=&show_inline=1">Query every entry that links to this</a></p>';
                      
                       print "<p><b><a href=\"/results.php?uri=$uri\">View entries related to this</a></b></p>";
                       print "</div>"; // end grid_5 omega
                       }
                      */
           
      } else {
          print "<h1>404 response</h1><p><strong>No entries found for $uri</strong></p>";
      }
     print '</div>'; 

 
     
 }
 
 // html footer
   public function  genHTMLFooter() {  
   print '</div>'; // End wrapper
    include 'includes/footer.php';
    print '</body>';
    print '</html>';
    }

    // html helper classes
    public function string_begins_with($string, $search)
    {
        return (strncmp($string, $search, strlen($search)) == 0);
    }
    
 
    
    public function uriOrString($i, $mode) {
        $output='';
              if ($this->string_begins_with(htmlspecialchars($i),'http://')) {
                   if ($mode=='link'){
                      $output=        '<a href="' . htmlspecialchars($i) . '">' .  htmlspecialchars($i) . '</a>';
                   } elseif ($mode=='triple') {
                       $output="<" . htmlspecialchars($i) .">";
                   }
                } else {        
              if ($mode=='link'){
                   $output=       htmlspecialchars($i);
                   } elseif ($mode=='triple') {
                       $output="\"" . htmlspecialchars($i). "\"";
                   }
                }
        return $output;
    }

}
?>