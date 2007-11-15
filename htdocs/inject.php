<?php

if($stream = @fsockopen('127.0.0.1', 6661, $errno, $errstr, 5)) {
	fputs($stream,$_GET['cmd']."\n");
	fclose($stream);
}
else {
  die;
}

?>
