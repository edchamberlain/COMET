<?php
include_once(dirname(__FILE__).'/config.php');
$uri = trim($_GET['uri'])|trim($_POST['uri']);

/* Render results */
$record= new cometDisplay;
//$record->initLinkedResults($uri, $store);
$record->initLinkedResultsFull($uri, $store);
?>
