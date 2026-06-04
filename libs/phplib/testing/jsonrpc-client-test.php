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

use Datto\JsonRpc\Client;


// Example 1. Single query
$client = new Client();

$client->query(1, 'LBSystem::get_miniservers', []);

$message = $client->encode();

echo "Example 1. Single query:\n{$message}\n\n";
// {"jsonrpc":"2.0","id":1,"method":"add","params":[1,2]}
