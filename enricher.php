#!/usr/bin/env php
<?php

/* PHP enrichment script for LOC identifiers  - Ed Chamberlain, CUL 2011 as part of the JISc funded COMET project
  - All work provided as is and licensed under the GPL
 
 Operation - requires a tri
 
*/

include_once(dirname(__FILE__).'/config.php');
$graph ='http://data.lib.cam.ac.uk/context/dataset/cambridge/bib';
#$uriFile = 'uri_tiny.txt';
$uriFile = 'uriSubject.txt';
# Stage #1 - interrogate triplestore for all DC subject URI's and write to text file ...
#getSubjectURIs($graph,$uriFile,$store);

# Stage #2 - ehrichment loop through text file ...
enrichURIs($graph, $uriFile, $store);

# END MAIN (yay)
######################

#Grab all URI's for subject nodes in Graph and writes a text file ...
function getSubjectURIs($graph,$uriFile,$store){

     $subjectAllQuery = "SELECT DISTINCT ?o WHERE {
      GRAPH <$graph> { ?s <http://purl.org/dc/terms/subject> ?o . }
    }";
      
    
     $uris =  $store->query($subjectAllQuery, 'rows');
     // print "<pre>";
     // var_dump($uris);
     // print "</pre>";
    
     
    $uriFile = 
    $file = fopen($uriFile,"w+") or die('cannot open text file for writing');
    $uriCount =0;
    foreach($uris as $uri ) {
      $uriEntry =  $uri['o'] . PHP_EOL;
     // print  $uriEntry;
      fwrite($file,$uriEntry) or die("cannot write URI $uri");
      $uriCount ++;
    }
    
    fclose($file);
    
    print "First stage (URI retrival) complete. $uriCount uri's written to $uriFile \n";
}
############


function enrichURIs($graph,$uriFile,$store) {
  $logfile = 'uriLog.txt';
  $log = fopen($logfile,"w+") or die('cannot open log file for writing');
  $hitCount = 0;
  $lines = file($uriFile);
  
    print "Commencing enrichment proccess ... \n";
  foreach($lines as $line)  {
      
      $line = trim($line);
      $uri = $line . '.nt';
     
        $options = array(
          'return_info'	=>false
      );
      $resultsString = load($uri,$options);
      $parser = ARC2::getRDFParser();
      $parser->parse($line,$resultsString);
      $results = $parser->getSimpleIndex();
       $subjectResults = $results["$line"];

    //  var_dump($subjectResults);
       # FIRST CHECK FOR PRESENCE OF  existing URI and skip   ...
           if (array_key_exists("http://purl.org/dc/terms/hasPart",$subjectResults)) {
                  fwrite($log,"$line - skipped, link already in place \n");
                    continue;
                  
           # N ext Check for existence of scheme
           } elseif (array_key_exists("http://www.w3.org/2004/02/skos/core#inScheme",$subjectResults)) {
           if ($subjectResults["http://www.w3.org/2004/02/skos/core#inScheme"][0] == "http://id.loc.gov/authorities#conceptScheme") {

                 if ($label = $subjectResults["http://www.w3.org/2004/02/skos/core#prefLabel"][0]) {
                            
                            // Chop up subject entry for URI label for LOC
                            $split= split(" -- ", $label);
                            $initialLabel = trim($split[0]);
                            
                         fwrite($log, "Subject entry label $line, label: $label = LOC, inital label entry: $initialLabel  \n");
  
                              // URI to interrogate id.loc.gov
                              $labelURI = 'http://id.loc.gov/authorities/label/'  . $initialLabel;
  
                              $URIoptions = array(
                                  'return_info'	=>true,
                                  'return_body' =>false
                              );
                              
                             $idResults = load($labelURI, $URIoptions );
                              
                           //  print "##################\n";
                           //  var_dump($idResults);
                           //  print "##################\n";
                           
                                  // SUCCESS! - Proceed with enrichment
                                  if  ($idResults["body"] == FALSE) {
                                  $enrichedURI = $idResults["headers"]["Location"];
                                   fwrite($log,"$line - URI found for $initialLabel - $enrichedURI \n");
                                  
                                 // Write new triple to store 
                                  $loadQuery = "INSERT INTO <$graph> {
                                                    <$line>  <http://purl.org/dc/terms/hasPart>  <$enrichedURI> .
                                                    }";
                                                    
                                     $store->query($loadQuery) or  fwrite($log, " Error writing  $enrichedURI \n");
                                     
                                
                                   $hitCount ++;
                                  } else {
                                      fwrite($log, $idResults["body"] . "\n");
                                        
                                  }
                            }
                        } else {
                           fwrite($log, "Subject entry $line not in LOC subject headings \n");
                  } // end array_key_exists
                  
           }
  }    // End lines loop
  
  print "\n Enrichment complete $hitCount labels matched to URI's ... \n";
  
   fclose($log);
} // end function



  
#################### Load subs from API common 
/**
 * Taken from http://www.bin-co.com/php/scripts/load/
 * Version : 2.00.A
 * Licesed under BSD
 */
function load($url,$options=array()) {
    $default_options = array(
        'method'        => 'get',
        'return_info'    => false,
        'return_body'    => true,
        'cache'            => false,
        'referer'        => '',
        'headers'        => array(),
        'session'        => false,
        'session_close'    => false,
        'xml_request'    => false,
    );
    // Sets the default options.
    foreach($default_options as $opt=>$value) {
        if(!isset($options[$opt])) $options[$opt] = $value;
    }

    $url_parts = parse_url($url);
    $ch = false;
    $info = array(//Currently only supported by curl.
        'http_code'    => 200
    );
    $response = '';
    
    $send_header = array(
        'Accept' => 'text/*',
        'User-Agent' => 'BinGet/1.00.A (http://www.bin-co.com/php/scripts/load/)'
    ) + $options['headers']; // Add custom headers provided by the user.
    
    if($options['cache']) {
        $cache_folder = '/tmp/php-load-function/';
        if(isset($options['cache_folder'])) $cache_folder = $options['cache_folder'];
        if(!file_exists($cache_folder)) {
            $old_umask = umask(0); // Or the folder will not get write permission for everybody.
            mkdir($cache_folder, 0777);
            umask($old_umask);
        }
        
        $cache_file_name = md5($url) . '.cache';
        $cache_file = joinPath($cache_folder, $cache_file_name); //Don't change the variable name - used at the end of the function.
                
        if(file_exists($cache_file)) { // Cached file exists - return that.
            $response = file_get_contents($cache_file);
            
             //Seperate header and content
            $separator_position = strpos($response,"\r\n\r\n");
            $header_text = substr($response,0,$separator_position);
            $body = substr($response,$separator_position+4);
            
            foreach(explode("\n",$header_text) as $line) {
                $parts = explode(": ",$line);
                if(count($parts) == 2) $headers[$parts[0]] = chop($parts[1]);
            }
            $headers['cached'] = true;
            
            if(!$options['return_info']) return $body;
            else return array('headers' => $headers, 'body' => $body, 'info' => array('cached'=>true));
        }
    }

    ///////////////////////////// Curl /////////////////////////////////////
    //If curl is available, use curl to get the data.
    if(function_exists("curl_init") 
                and (!(isset($options['use']) and $options['use'] == 'fsocketopen'))) { //Don't use curl if it is specifically stated to use fsocketopen in the options
        
        if(isset($options['post_data'])) { //There is an option to specify some data to be posted.
            $page = $url;
            $options['method'] = 'post';
            
            if(is_array($options['post_data'])) { //The data is in array format.
                $post_data = array();
                foreach($options['post_data'] as $key=>$value) {
                    $post_data[] = "$key=" . urlencode($value);
                }
                $url_parts['query'] = implode('&', $post_data);
            
            } else { //Its a string
                $url_parts['query'] = $options['post_data'];
            }
        } else {
            if(isset($options['method']) and $options['method'] == 'post') {
                $page = $url_parts['scheme'] . '://' . $url_parts['host'] . $url_parts['path'];
            } else {
                $page = $url;
            }
        }
   
        // EC amendment - additional clause for XML requests ...
        if ($options['xml_request']) {
         $page .= $options['xml_request'];
        }
        

        if($options['session'] and isset($GLOBALS['_binget_curl_session'])) $ch = $GLOBALS['_binget_curl_session']; //Session is stored in a global variable
        else $ch = curl_init($url_parts['host']);
        
        curl_setopt($ch, CURLOPT_URL, $page) or die("Invalid cURL Handle Resouce");
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); //Just return the data - not print the whole thing.
        curl_setopt($ch, CURLOPT_HEADER, true); //We need the headers
        curl_setopt($ch, CURLOPT_NOBODY, !($options['return_body'])); //The content - if true, will not download the contents. There is a ! operation - don't remove it.
        if(isset($options['method']) and $options['method'] == 'post' and isset($url_parts['query'])) {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $url_parts['query']);
        }
        //Set the headers our spiders sends
        curl_setopt($ch, CURLOPT_USERAGENT, $send_header['User-Agent']); //The Name of the UserAgent we will be using ;)
        $custom_headers = array("Accept: " . $send_header['Accept'] );
        if(isset($options['modified_since']))
            array_push($custom_headers,"If-Modified-Since: ".gmdate('D, d M Y H:i:s \G\M\T',strtotime($options['modified_since'])));
        curl_setopt($ch, CURLOPT_HTTPHEADER, $custom_headers);
        if($options['referer']) curl_setopt($ch, CURLOPT_REFERER, $options['referer']);

        curl_setopt($ch, CURLOPT_COOKIEJAR, "/tmp/binget-cookie.txt"); //If ever needed...
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_MAXREDIRS, 5);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

        if(isset($url_parts['user']) and isset($url_parts['pass'])) {
            $custom_headers = array("Authorization: Basic ".base64_encode($url_parts['user'].':'.$url_parts['pass']));
            curl_setopt($ch, CURLOPT_HTTPHEADER, $custom_headers);
        }

        $response = curl_exec($ch);
        $info = curl_getinfo($ch); //Some information on the fetch
        
        if($options['session'] and !$options['session_close']) $GLOBALS['_binget_curl_session'] = $ch; //Dont close the curl session. We may need it later - save it to a global variable
        else curl_close($ch);  //If the session option is not set, close the session.

    //////////////////////////////////////////// FSockOpen //////////////////////////////
    } else { //If there is no curl, use fsocketopen - but keep in mind that most advanced features will be lost with this approch.
        if(isset($url_parts['query'])) {
            if(isset($options['method']) and $options['method'] == 'post')
                $page = $url_parts['path'];
            else
                $page = $url_parts['path'] . '?' . $url_parts['query'];
        } else {
            $page = $url_parts['path'];
        }
        
        if(!isset($url_parts['port'])) $url_parts['port'] = 80;
        $fp = fsockopen($url_parts['host'], $url_parts['port'], $errno, $errstr, 30);
        if ($fp) {
            $out = '';
            if(isset($options['method']) and $options['method'] == 'post' and isset($url_parts['query'])) {
                $out .= "POST $page HTTP/1.1\r\n";
            } else {
                $out .= "GET $page HTTP/1.0\r\n"; //HTTP/1.0 is much easier to handle than HTTP/1.1
            }
            $out .= "Host: $url_parts[host]\r\n";
            $out .= "Accept: $send_header[Accept]\r\n";
            $out .= "User-Agent: {$send_header['User-Agent']}\r\n";
            if(isset($options['modified_since']))
                $out .= "If-Modified-Since: ".gmdate('D, d M Y H:i:s \G\M\T',strtotime($options['modified_since'])) ."\r\n";

            $out .= "Connection: Close\r\n";
            
            //HTTP Basic Authorization support
            if(isset($url_parts['user']) and isset($url_parts['pass'])) {
                $out .= "Authorization: Basic ".base64_encode($url_parts['user'].':'.$url_parts['pass']) . "\r\n";
            }

            //If the request is post - pass the data in a special way.
            if(isset($options['method']) and $options['method'] == 'post' and $url_parts['query']) {
                $out .= "Content-Type: application/x-www-form-urlencoded\r\n";
                $out .= 'Content-Length: ' . strlen($url_parts['query']) . "\r\n";
                $out .= "\r\n" . $url_parts['query'];
            }
            $out .= "\r\n";

            fwrite($fp, $out);
            while (!feof($fp)) {
                $response .= fgets($fp, 128);
            }
            fclose($fp);
        }
    }

    //Get the headers in an associative array
    $headers = array();

    if($info['http_code'] == 404) {
        $body = "";
        $headers['Status'] = 404;
    } else {
        
        // EC Amendment - the abustr approach to header body seperation not working, still giving out 5 header + lines in body, so using code from V1 which looks for line breaks then adds 4 (also a bit creaky ...)
        //Seperate header and content
     //   $header_text = substr($response, 0, $info['header_size']);
      //  $body = substr($response, $info['header_size']);
      
        $separator_position = strpos($response,"\r\n\r\n");
        $header_text = substr($response,0,$separator_position);
        $body = substr($response,$separator_position+4);
        
        foreach(explode("\n",$header_text) as $line) {
            $parts = explode(": ",$line);
            if(count($parts) == 2) $headers[$parts[0]] = chop($parts[1]);
        }
    }
    
    if(isset($cache_file)) { //Should we cache the URL?
        file_put_contents($cache_file, $response);
    }

    if($options['return_info']){
        return array('headers' => $headers, 'body' => $body, 'info' => $info, 'curl_handle'=>$ch);
    } else {
        return $body;   
    }
    
}
?>