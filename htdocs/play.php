<?php

if($stream = @fsockopen('127.0.0.1', 6661, $errno, $errstr, 5)) {
	fputs($stream,'zone:1|screen:now_playing|cmd:'.$_GET['cmd']."\n");
	fclose($stream);
}

?>
