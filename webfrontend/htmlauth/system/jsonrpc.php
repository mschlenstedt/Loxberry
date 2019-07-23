<?php

class Autoloader
{
    public static function register()
    {
        spl_autoload_register(function ($class) {
            $file = str_replace('\\', DIRECTORY_SEPARATOR, $class).'.php';
            if (file_exists($file)) {
                require $file;
                return true;
            }
            return false;
        });
    }
}
Autoloader::register();

$args = $argv;
array_shift($args);
$jsonquery = join(" ", $args);
echo "Arg: $jsonquery\n";




use Datto\JsonRpc\Evaluator;
use Datto\JsonRpc\Exceptions\ArgumentException;
use Datto\JsonRpc\Exceptions\MethodException;
use Datto\JsonRpc\Server;
use LoxBerry\JsonRpcApi;

$server = new Server(new Api());

$reply = $server->reply($jsonquery);

echo $reply, "\n"; // {"jsonrpc":"2.0","id":1,"result":3}













