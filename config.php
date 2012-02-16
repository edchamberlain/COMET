<?php
include_once(dirname(__FILE__).'/arc/ARC2.php'); // path to the file ARC2.php
include_once(dirname(__FILE__).'/comet/comet.php');


// SQL database configuration for storing the postings:
$arc_config = array(
  /* MySQL database settings COMPLETE!*/
  'db_host' => '',
  'db_user' => '',
  'db_pwd' => '',
  'db_name' => '',

  /* ARC2 store settings - change if required - will be used to prefix all tables for store in MYSQL database*/
  'store_name' => 'comet',

  /* SPARQL endpoint settings */
  'endpoint_features' => array(
    'select', 'construct', 'ask', 'describe' // allow read
    //'load', 'insert', 'delete',           // allow update
  //  'dump'
  ),
  'endpoint_timeout' => 360, /* not implemented in ARC2 preview */
  'endpoint_read_key' => '', /* optional */
  'endpoint_write_key' => '', /* optional */
  'endpoint_max_limit' =>10000                          
);

// Replace with remoteStore if you don't want to use the arc2 internal store.
/* store instantiation */
$store = ARC2::getStore($arc_config);

if (!$store->isSetUp()) {
  $store->setUp(); /* create MySQL tables */
}

?>