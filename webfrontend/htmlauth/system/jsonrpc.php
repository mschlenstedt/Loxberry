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

$args = $argv;
array_shift($args);
$jsonquery = join(" ", $args);
# echo "Arg: $jsonquery\n";

use Datto\JsonRpc\Evaluator;
use Datto\JsonRpc\Exceptions\ArgumentException;
use Datto\JsonRpc\Exceptions\MethodException;
use Datto\JsonRpc\Server;
use LoxBerry\JsonRpcApi;

$server = new Server(new JsonRpcApi());

$reply = $server->reply($jsonquery);

echo $reply, "\n"; // {"jsonrpc":"2.0","id":1,"result":3}
