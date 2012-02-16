<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp
/DTD/xhtml-rdfa-1.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"
  xml:lang="en-US">
<head>
<title>Library open data site!</title>

<?php include 'includes/css.php'; ?>

</head>
<body class="home"><div class="container">

<?php include 'includes/header.php';?>

<div class="main">
   <p>Welcome page text here</p>
   <?php
include_once(dirname(__FILE__).'/config.php');
$result = $store->query("SELECT DISTINCT ?property WHERE { ?subject ?property ?object . }");
$rows = $result["result"]["rows"];

if ($rows) {
    print "<table border='1'>\n";
    print "<tr><th>Properties currently in use in the triple store</th></tr>\n";

    foreach ($rows as $row) {
        $item = $row["property"];
        if (strpos($item, "http://www.w3.org/1999/02/22-rdf-syntax-ns#_") !== 0) {
            print "<tr><td>" . htmlspecialchars($item) . "</td></tr>\n";
        }
    }

    print "</table>\n";
} else {
    print "<strong>The ARC2 triple store is currently empty.\n";
    print "Please load some data first.</strong>";
}


?>
</div>
<?php include 'includes/footer.php';?>
</div>
</body>

</html>
