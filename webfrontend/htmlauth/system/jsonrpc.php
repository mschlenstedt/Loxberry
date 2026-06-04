<?php

require_once "loxberry_system.php";

// autoload classes based on a 1:1 mapping from namespace to directory structure.
spl_autoload_register(function ($className) {

    # Usually I would just concatenate directly to $file variable below
    # this is just for easy viewing on Stack Overflow)
        $ds = DIRECTORY_SEPARATOR;
        $dir = LBHOMEDIR . "/libs/phplib";

    // replace namespace separator with directory separator (prolly not required)
        $className = str_replace('\\', $ds, $className);

    // get full name of file containing the required class
        $file = "{$dir}{$ds}{$className}.php";

    // get file if it is readable
        if (is_readable($file)) require_once $file;
});

if(isCommandLineInterface()) {
	$args = $argv;
	array_shift($args);
	$jsonquery = join(" ", $args);
	# echo "Arg: $jsonquery\n";
} else {
	$jsonquery = file_get_contents('php://input');
	error_log("Received: $jsonquery");
}
	
	
use Datto\JsonRpc\Evaluator;
use Datto\JsonRpc\Exceptions\ArgumentException;
use Datto\JsonRpc\Exceptions\MethodException;
use Datto\JsonRpc\Server;
use LoxBerry\JsonRpcApi;

$server = new Server(new JsonRpcApi());

ob_start();
$reply = $server->reply($jsonquery);
$fromstdout = ob_get_contents();
ob_end_clean();

error_log("Reply from JsonRpc Server: $reply");

if(!empty($fromstdout) && isset($reply)) {
	// error_log("STDOUT not empty: $fromstdout");
	$jsondata = json_decode($reply);
	// error_log("id: ".$jsondata[0]->id);
	// error_log(var_export($jsondata, true));
	// var_dump($jsondata);
	if($jsondata[0]->result == null ) {
		$jsondata[0]->result = $fromstdout;
		$reply = json_encode($jsondata, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_NUMERIC_CHECK );
		// error_log("New json data: $reply");
	}
}

if(!isCommandLineInterface()) {
	header('Content-Type: application/json');
}
echo $reply, "\n"; // {"jsonrpc":"2.0","id":1,"result":3}



function isCommandLineInterface()
{
    return (php_sapi_name() === 'cli');
}
