<?php
include_once(dirname(__FILE__).'/config.php');
$label = trim($_GET['label'])|trim($_POST['label']);
$label = urldecode($label);
/* Render results */
$record= new cometDisplay;
//$record->initLinkedResults($uri, $store);

if ($newuri = $record->getURIfromLabel($label, $store)) {
     header("Location: $newuri");
     exit;
} else {
   print "<p>No URI found for label or prefLabel: $label</p>" ;
}
?>
