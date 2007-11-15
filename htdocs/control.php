<?php

ob_end_flush();
echo str_pad('',1024)."	\t<br>\n";
flush();

$idx = 1;
if($stream = @fsockopen('127.0.0.1', 6661, $errno, $errstr, 5)) {
	stream_set_timeout($stream, 10);
	$s = stream_get_meta_data($stream);
	$contents = '';
	while(!feof($stream) && !$s['timed_out']) {
		$contents .= fgets($stream,2);
		if(!preg_match('/\n/s',$contents)) continue;

		$contents = preg_replace('/[\r\n]/','',$contents);
		$contents = preg_replace("/'/",'"',$contents);

		foreach(explode('||',$contents) as $bit) {
			preg_match('/([^:]+):(.+)?/',$bit,$matches);
			if($matches[1] == 'lines') {
				$ln = 1;
				echo "<script>parent.document.getElementById('lines').innerHTML = '';</script>\n";
				foreach(explode(';',$matches[2]) as $line) {
					if($line != '~') echo "<script>parent.document.getElementById('lines').innerHTML += '<a href=\"#\" onclick=\"controller2.location=\\'inject.php?cmd=\\'+escape(\\'zone:1|screen:library|cmd:menu_select|line_number:$ln\\');return false;\">$line</a><br>';</script>\n";
					$ln++;
				}
			} elseif($matches[1] == 'random') {
				echo "<script>parent.rndm(".$matches[2].");</script>\n";
			} elseif($matches[1] == 'repeat') {
				echo "<script>parent.repeat(".$matches[2].");</script>\n";
			} elseif($matches[1] == 'state') {
				echo "<script>parent.state = '".$matches[2]."';</script>\n";
			} elseif($matches[1] != 'cmd' && $matches[1] != 'zone') {
				echo "<script>parent.doit('".$matches[1]."','".$matches[2]."');</script>\n";
			}
			flush();
		}

		if($idx++ == 50) echo "<script>location = 'control.php';</script>\n";

		$s = stream_get_meta_data($stream);
		$contents = '';
	}

	fclose($stream);
}

?>
